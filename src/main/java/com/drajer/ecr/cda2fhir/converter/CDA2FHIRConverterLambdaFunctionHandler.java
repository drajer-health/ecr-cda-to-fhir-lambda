package com.drajer.ecr.cda2fhir.converter;

import java.io.BufferedReader;
import java.io.ByteArrayInputStream;
import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.nio.charset.Charset;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.Map;
import java.util.UUID;

import javax.xml.transform.Source;
import javax.xml.transform.stream.StreamSource;

import org.apache.http.HttpResponse;
import org.apache.http.client.ClientProtocolException;
import org.apache.http.client.config.RequestConfig;
import org.apache.http.client.methods.HttpPost;
import org.apache.http.entity.StringEntity;
import org.apache.http.impl.client.CloseableHttpClient;
import org.apache.http.impl.client.HttpClientBuilder;
import org.springframework.util.ResourceUtils;

import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.RequestHandler;
import com.amazonaws.services.s3.AmazonS3;
import com.amazonaws.services.s3.AmazonS3ClientBuilder;
import com.amazonaws.services.s3.model.AmazonS3Exception;
import com.amazonaws.services.s3.model.GetObjectRequest;
import com.amazonaws.services.s3.model.ObjectMetadata;
import com.amazonaws.services.s3.model.S3Object;
import com.amazonaws.services.s3.model.S3ObjectInputStream;
import com.amazonaws.util.StringUtils;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.saxonica.config.ProfessionalConfiguration;

import net.sf.saxon.lib.FeatureKeys;
import net.sf.saxon.s9api.Processor;
import net.sf.saxon.s9api.SaxonApiException;
import net.sf.saxon.s9api.Serializer;
import net.sf.saxon.s9api.XsltCompiler;
import net.sf.saxon.s9api.XsltExecutable;
import net.sf.saxon.s9api.XsltTransformer;

public class CDA2FHIRConverterLambdaFunctionHandler implements RequestHandler<Map<String, Object>, String> {
	private AmazonS3 s3Client = AmazonS3ClientBuilder.standard().build();
	private String destPath = System.getProperty("java.io.tmpdir");
	public static final int DEFAULT_BUFFER_SIZE = 8192;
	private static CDA2FHIRConverterLambdaFunctionHandler instance;
	private XsltTransformer transformer;
	private Processor processor;	

	public static CDA2FHIRConverterLambdaFunctionHandler getInstance() throws IOException {
		if (instance == null) {
			synchronized (CDA2FHIRConverterLambdaFunctionHandler.class) {
				if (instance == null) {
					instance = new CDA2FHIRConverterLambdaFunctionHandler();
				}
			}
		}
		return instance;
	}	
	
	public CDA2FHIRConverterLambdaFunctionHandler() throws IOException {
		String bucketName = System.getenv("BUCKET_NAME");
		if (bucketName == null || bucketName.isEmpty()) {
			throw new IllegalArgumentException("S3 bucket name is not set in the environment variables.");
		}		
		// Load the Saxon processor and transformer
		this.processor = createSaxonProcessor();
		this.transformer = initializeTransformer();
	}	
	
	private Processor createSaxonProcessor() throws IOException {
		String bucketName = System.getenv("LICENSE_BUCKET_NAME");
		String licenseFilePath = "/tmp/saxon-license.lic"; // Ensure temp path is used
		ProfessionalConfiguration configuration = new ProfessionalConfiguration();
		String key = "license/saxon-license.lic";

		// Attempt to retrieve the license file from S3
		S3Object licenseObj;
		try {
			licenseObj = s3Client.getObject(bucketName, key);
		} catch (AmazonS3Exception e) {
			throw new IOException("Failed to retrieve the license file from S3 bucket: " + bucketName, e);
		}

		// Read the license file
		try (S3ObjectInputStream s3InputStream = licenseObj.getObjectContent();
				FileOutputStream fos = new FileOutputStream(new File(licenseFilePath))) {

			byte[] readBuf = new byte[DEFAULT_BUFFER_SIZE];
			int readLen;
			while ((readLen = s3InputStream.read(readBuf)) > 0) {
				fos.write(readBuf, 0, readLen);
			}
		}

		// Check if the license file was saved correctly
		File licenseFile = ResourceUtils.getFile(licenseFilePath);
		if (!licenseFile.exists() || licenseFile.length() == 0) {
			throw new IOException("License file not found or is empty at: " + licenseFilePath);
		}

		String saxonLicenseAbsolutePath = licenseFile.getAbsolutePath();
		System.setProperty("http://saxon.sf.net/feature/licenseFileLocation", saxonLicenseAbsolutePath);
		configuration.setConfigurationProperty(FeatureKeys.LICENSE_FILE_LOCATION, saxonLicenseAbsolutePath);

		return new Processor(configuration);
	}
	
	private XsltTransformer initializeTransformer() {
		try {
			File xsltFile = ResourceUtils
					.getFile("classpath:hl7-xml-transforms/transforms/cda2fhir-r4/NativeUUIDGen-cda2fhir.xslt");
			processor.setConfigurationProperty(FeatureKeys.ALLOW_MULTITHREADING, true);
			XsltCompiler compiler = processor.newXsltCompiler();

//			compiler.setJustInTimeCompilation(true);
			XsltExecutable executable = compiler.compile(new StreamSource(xsltFile));
			return executable.load();
		} catch (SaxonApiException | IOException e) {
			throw new RuntimeException("Failed to initialize XSLT Transformer", e);
		}
	}
	
	@Override
	public String handleRequest(Map<String, Object> event, Context context) {
		InputStream input = null;
		File outputFile = null;
		String keyFileName = "";
		String keyPrefix = "";
		try {
			instance = CDA2FHIRConverterLambdaFunctionHandler.getInstance();
			ArrayList records = (ArrayList) event.get("Records");
			Map<String, Object> inputMap = (Map<String, Object>) records.get(0);
			String jsonBody = (String) inputMap.get("body");
			ObjectMapper objectMapper = new ObjectMapper();
			JsonNode rootNode = objectMapper.readTree(jsonBody);
			
			JsonNode detailNode = rootNode.get("detail");
			if (detailNode == null) {
				detailNode = rootNode;
			}
			JsonNode bucketNode = detailNode.get("bucket");
			JsonNode keyObjectNode = detailNode.get("object");
			
			String bucket = bucketNode.get("name").asText();
			String key = keyObjectNode.get("key").asText(); // record.getS3().getObject().getKey();

			context.getLogger().log("BucketName : " + bucket);
			context.getLogger().log("Key:" + key);

			String soureFolder = "FHIRConvertSubmissionV2";
			String envVar = System.getenv("SOURCE_FOLDER");
			
			if (envVar == null || envVar.isEmpty()) {
				context.getLogger().log("Source Folder is not set in the environment variables.");
			}else {
				soureFolder = envVar;
			}
			
			String targerFolder = "RRMessageFHIRV2";
			envVar = System.getenv("TARGET_FOLDER");
			if (envVar == null || envVar.isEmpty()) {
				context.getLogger().log("Target Folder is not set in the environment variables.");
			}else {
				targerFolder = envVar;
			}
			
			context.getLogger().log("Source Folder value : "+soureFolder);
			context.getLogger().log("Target Folder value : "+targerFolder);
			
			if (key != null && key.indexOf(File.separator) != -1) {
				keyFileName = key.substring(key.lastIndexOf(File.separator));
				keyPrefix = key.replace(soureFolder,targerFolder);
			} else {
				keyFileName = key;
			}

			context.getLogger().log("JVM - Temp Folder Path:::" + destPath);

			if (!this.isConverterBucket(bucket)) {
				context.getLogger().log(
						"BUCKET_NAME env null; Env BUCKET_NAME should match the bucket name created for converter ");
				return "Error: Different Bucket";
			}

			S3Object s3Object = s3Client.getObject(new GetObjectRequest(bucket, key));
			input = s3Object.getObjectContent();
			outputFile = new File("/tmp/" + keyFileName);

			outputFile.setWritable(true);

			context.getLogger().log("Output File----" + outputFile.getAbsolutePath());
			context.getLogger().log("Output File -- CanWrite?:" + outputFile.canWrite());
			context.getLogger().log("Output File -- Length:" + outputFile.length());

			try (FileOutputStream outputStream = new FileOutputStream(outputFile, false)) {
				int read;
				byte[] bytes = new byte[DEFAULT_BUFFER_SIZE];
				while ((read = input.read(bytes)) != -1) {
					outputStream.write(bytes, 0, read);
				}
				outputStream.close();
			}

			context.getLogger().log("Output File -- Length:" + outputFile.length());
			context.getLogger().log("---- s3Object-Content....:" + s3Object.getObjectMetadata().getContentType());

			UUID randomUUID = UUID.randomUUID();
//			File xsltFile = ResourceUtils.getFile("classpath:hl7-xml-transforms/transforms/cda2fhir-r4/NativeUUIDGen-cda2fhir.xslt");

//			context.getLogger().log("--- Before Transformation XSLT---::" + xsltFile.getAbsolutePath());
			context.getLogger().log("--- Before Transformation OUTPUT---::" + outputFile.getAbsolutePath());
			context.getLogger().log("--- Before Transformation UUID---::" + randomUUID);

//			xsltTransformation(xsltFile.getAbsolutePath(), outputFile.getAbsolutePath(), randomUUID, context);
			
			instance.transform(outputFile, randomUUID, context);
			
			
			String responseXML = getFileContentAsString(randomUUID, context);

			if (StringUtils.isNullOrEmpty(responseXML)) {
				context.getLogger().log("Output not generated check logs ");
			} else {
				context.getLogger().log("Writing output file ");
				this.writeFhirFile(responseXML, bucket, keyPrefix, context);
				context.getLogger().log("Output Generated  "+bucket+"/"+keyPrefix);
				// Call Validation on RR FHIR
				keyPrefix= keyPrefix.replace(targerFolder,"RRValidationMessageFHIRV2");
				validateRRFhir(responseXML, bucket,keyPrefix , context);
				
			}
			return "SUCCESS";
		} catch (Exception e) {
			context.getLogger().log(e.getMessage());
			context.getLogger().log("Exception in CDA2FHIR ");
			e.printStackTrace();
			return "ERROR:" + e.getMessage();
		} finally {
			if (input != null)
				try {
					input.close();
				} catch (Exception e) {
				}
			if (outputFile != null)
				outputFile.deleteOnExit();
		}
	}
	public void transform(File sourceXml, UUID outputFileName, Context context) {
		try {
			Source source = new StreamSource(sourceXml);
			Path outputPath = Paths.get("/tmp", outputFileName.toString() );
			Files.createDirectories(outputPath.getParent());

			Serializer out = processor.newSerializer(outputPath.toFile());
			out.setOutputProperty(Serializer.Property.METHOD, "xml");

			transformer.setSource(source);
			transformer.setDestination(out);
			transformer.transform();

			context.getLogger().log("Transformation complete. Output saved to: " + outputPath);
		} catch (SaxonApiException e) {
			context.getLogger().log("ERROR: Transformation failed with exception: " + e.getMessage());
		} catch (IOException e) {
			context.getLogger().log("ERROR: Failed to create output directory or file: " + e.getMessage());
		} catch (Exception e) {
			context.getLogger().log("ERROR: Unexpected error occurred: " + e.getMessage());
		}
	}	

	private String getFileContentAsString(UUID fileName, Context context) {

		File outputFile = null;
		try {
			outputFile = ResourceUtils.getFile("/tmp/" + fileName );
			String absolutePath = outputFile.getAbsolutePath();
			byte[] readAllBytes = Files.readAllBytes(Paths.get(absolutePath));
			Charset encoding = Charset.defaultCharset();
			String string = new String(readAllBytes, encoding);
			return string;

		} catch (FileNotFoundException e) {
			context.getLogger().log("ERROR: output file not found " + e.getMessage());
		} catch (IOException e) {
			context.getLogger().log("ERROR: IO Exception while reading output file " + e.getMessage());
		} catch (Exception ee) {
			context.getLogger().log("ERROR: Exception for output " + ee.getMessage());
		}
		return null;
	}

	/**
	 * Check if the S3 file processing is from the same S3 Converter bucket
	 * 
	 * @param theBucketName
	 * @return
	 */
	private boolean isConverterBucket(String theBucketName) {

		String envBucketName = System.getenv("BUCKET_NAME");
		if (envBucketName != null && theBucketName != null && theBucketName.equalsIgnoreCase(envBucketName)) {
			return true;
		}
		return false;
	}

	private void writeFhirFile(String theFileContent, String theBucketName, String theKeyPrefix, Context context) {
		try {
			byte[] contentAsBytes = theFileContent.getBytes("UTF-8");
			ByteArrayInputStream is = new ByteArrayInputStream(contentAsBytes);
			ObjectMetadata meta = new ObjectMetadata();
			meta.setContentLength(contentAsBytes.length);
			meta.setContentType("text/xml");

			// Uploading to S3 destination bucket
			s3Client.putObject(theBucketName, theKeyPrefix, is, meta);
			is.close();
		} catch (Exception e) {
			context.getLogger().log("ERROR:" + e.getMessage());
			e.printStackTrace();
		}
	}
	
	private void validateRRFhir(String requestBody, String theBucketName, String theKeyPrefix, Context context) {
		// URL where the request will be forwarded
		String httpPostUrl = System.getenv("VALIDATION_URL");

//		System.out.println("requestBody :::::"+requestBody);
		if (httpPostUrl == null) {
			throw new RuntimeException("VALIDATION_URL Environment variable not configured");
		}
		context.getLogger().log("HTTP Post URL : " + httpPostUrl);
		// Create a instance of httpClient and forward the request
//		DefaultHttpClient httpClient = new DefaultHttpClient();

		int timeout = 15;
		RequestConfig config = RequestConfig.custom().setConnectTimeout(timeout * 1000)
				.setConnectionRequestTimeout(timeout * 1000).setSocketTimeout(timeout * 1000).build();
		CloseableHttpClient httpClient = HttpClientBuilder.create().setDefaultRequestConfig(config).build();
		try {
			// Add content type as application / json
			HttpPost postRequest = new HttpPost(httpPostUrl);
			postRequest.addHeader("accept", "application/xml");
			
//			JSONObject json = XML.toJSONObject(requestBody);
//			String jsonString = json.toString();
			StringEntity input = new StringEntity(requestBody);
//			context.getLogger().log("Forwarding the jsonString : "+jsonString);
			
			input.setContentType("application/xml");
			postRequest.setEntity(input);

			context.getLogger().log("Forwarding the request to FHIR Validator ");
			context.getLogger().log("Request Body Content Size " + input.getContentLength());

			// logger.log(inputStrBuilder.toString());

			HttpResponse response = null;
			try {
				context.getLogger().log("Making the HTTP Post to " + httpPostUrl);
				response = httpClient.execute(postRequest);
				context.getLogger().log("HTTP Post completed ");
			} catch (Exception e) {
				context.getLogger().log(" In HTTP Post Exception " + e.getLocalizedMessage());
				e.printStackTrace();
			}

			// Check return status and throw Runtime exception for return code != 200
			if (response != null && response.getStatusLine().getStatusCode() != 200) {
				context.getLogger().log("Post Message failed with Code: " + response.getStatusLine().getStatusCode());
				context.getLogger().log("Post Message failed reason: " + response.getStatusLine().getReasonPhrase());
				context.getLogger().log("Post Message response body: " + response.toString());
				throw new RuntimeException("Failed : HTTP error code : " + response.getStatusLine().getStatusCode());
			}
			StringBuilder outputStr = new StringBuilder();
			
			context.getLogger().log("Response status code: "+response.getStatusLine().getStatusCode());

			if (response != null) {
				BufferedReader br = new BufferedReader(new InputStreamReader((response.getEntity().getContent())));
				String output;
				context.getLogger().log("Response from FHIR Validator .... ");
				// Write the response back to invoking program
				while ((output = br.readLine()) != null) {
					outputStr.append(output);
				}
				br.close();
			}
			context.getLogger().log("Validation Output : " + outputStr.toString());
			
			context.getLogger().log("Write output to bucket : " + theBucketName);
			context.getLogger().log("Write output to filename : " + theKeyPrefix);
			this.writeFhirFile(outputStr.toString(), theBucketName, theKeyPrefix, context);
			
		} catch (ClientProtocolException e) {
			context.getLogger().log("Failed with ClientProtocolException " + e.getMessage());
			throw new RuntimeException("Failed with ClientProtocolException: " + e.getMessage());
		} catch (IOException e) {
			context.getLogger().log("Failed with IOException " + e.getMessage());
			throw new RuntimeException("Failed with IOException: " + e.getMessage());
		} finally {
			context.getLogger().log("Closing HTTP Connection to " + httpPostUrl);
			try {
				httpClient.close();
			} catch (IOException e) {
				context.getLogger().log("Failed with close connection " + e.getMessage());
			}

		}

	}
}