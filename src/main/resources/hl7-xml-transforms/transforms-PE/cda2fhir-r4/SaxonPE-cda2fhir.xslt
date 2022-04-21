<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
   xmlns="http://hl7.org/fhir"
                xmlns:lcg="http://www.lantanagroup.com"
                xmlns:cda="urn:hl7-org:v3"
                xmlns:fhir="http://hl7.org/fhir"
                xmlns:uuid="java:java.util.UUID"
                version="2.0"
                exclude-result-prefixes="lcg cda uuid fhir">

   <xsl:import href="cda2fhir-includes.xslt"/>
   <xsl:import href="cda-add-uuid.xslt"/>

   <xsl:output method="xml" indent="yes" encoding="UTF-8" />
   <xsl:strip-space elements="*"/>
   
   <xsl:template match="/">
      <xsl:variable name="element-count" select="count(//cda:*)"/>
      <xsl:message>Element count: <xsl:value-of select="$element-count"/></xsl:message>
      <!-- Preprocesses the CDA document, adding UUIDs where needed to generate resources and references later -->
      <xsl:variable name="pre-processed-cda">
         <xsl:apply-templates select="." mode="add-uuids"/>
      </xsl:variable>
      <!-- This is where processing actually starts --> 
      <xsl:apply-templates select="$pre-processed-cda" mode="convert"/>
   </xsl:template>
</xsl:stylesheet>
