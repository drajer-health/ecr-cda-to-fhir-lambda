<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns="http://hl7.org/fhir" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:fhir="http://hl7.org/fhir" xmlns:cda="urn:hl7-org:v3"
  xmlns:lcg="http://www.lantanagroup.com" exclude-result-prefixes="xs fhir cda lcg" version="2.0">

  <xsl:import href="c-to-fhir-utility.xslt" />
  <xsl:output indent="yes" />

  <!-- create bundle-entry for RR externalDocument as DocumentReference -->
  <xsl:template match="cda:act[cda:templateId/@root = '2.16.840.1.113883.10.20.15.2.3.9']" mode="bundle-entry">
    <entry>
      <fullUrl value="urn:uuid:{cda:reference/cda:externalDocument/@lcg:uuid}" />
      <resource>
        <xsl:apply-templates select="cda:reference/cda:externalDocument" />
      </resource>
    </entry>
  </xsl:template>

  <!-- create DocumentReference from externalDocument -->
  <xsl:template match="cda:externalDocument">
    <DocumentReference>
      <status value="current" />

      <xsl:apply-templates select="cda:code"> 
        <xsl:with-param name="pElementName" select="'type'" />
      </xsl:apply-templates>

      <content>
        <attachment>
          <url>
            <xsl:choose>
              <xsl:when test="cda:setId/@root and cda:versionId/@value">
                <xsl:attribute name="value" select="concat('urn:hl7ii:', cda:setId/@root, ':', cda:versionId/@value)" />
              </xsl:when>
              <xsl:when test="cda:setId/@root">
                <xsl:attribute name="value" select="concat('urn:oid:', cda:setId/@root)" />
              </xsl:when>
              <xsl:otherwise>
                <xsl:comment>URL cannot be determined because CDA document does not have a cda:setId for the cda:externalDocument</xsl:comment>
              </xsl:otherwise>
            </xsl:choose>
          </url>
        </attachment>
      </content>
    </DocumentReference>
  </xsl:template>
  
  <!-- create DocumentReference from 2.16.840.1.113883.10.20.15.2.3.10 eICR External Document Reference externalDocument -->
  <xsl:template match="cda:externalDocument[cda:templateId/@root='2.16.840.1.113883.10.20.15.2.3.10']">
    <DocumentReference>
      
      <!-- ClinicalDocument.id -->
      <xsl:apply-templates select="cda:id">
        <xsl:with-param name="pElementName" select="'masterIdentifier'"/>
      </xsl:apply-templates>
      <!-- ClinicalDocument.setId and versionNumber -->
      <xsl:call-template name="createIdentifierWithVersionNumber"/>
      
      <status value="current" />
      
      <xsl:apply-templates select="cda:code"> 
        <xsl:with-param name="pElementName" select="'type'" />
      </xsl:apply-templates>
      
      <content>
        <attachment>
          <url>
            <xsl:choose>
              <xsl:when test="cda:setId/@root and cda:versionId/@value">
                <xsl:attribute name="value" select="concat('urn:hl7ii:', cda:setId/@root, ':', cda:versionId/@value)" />
              </xsl:when>
              <xsl:when test="cda:setId/@root">
                <xsl:attribute name="value" select="concat('urn:oid:', cda:setId/@root)" />
              </xsl:when>
              <xsl:otherwise>
                <xsl:comment>URL cannot be determined because CDA document does not have a cda:setId for the cda:externalDocument</xsl:comment>
              </xsl:otherwise>
            </xsl:choose>
          </url>
        </attachment>
      </content>
    </DocumentReference>
  </xsl:template>
  
  <!-- This is a workaround to get versionNumber in -->
  <xsl:template name="createIdentifierWithVersionNumber">
    <xsl:param name="pElementName">identifier</xsl:param>
    <xsl:variable name="mapping" select="document('../oid-uri-mapping-r4.xml')/mapping" />
    <xsl:variable name="oid" select="cda:setId/@root" />
    <xsl:variable name="root-uri">
      <xsl:choose>
        <xsl:when test="$mapping/map[@oid = cda:setId/$oid]">
          <xsl:value-of select="$mapping/map[@oid = cda:setId/$oid][1]/@uri" />
        </xsl:when>
        <xsl:when test="contains(cda:setId/@root, 'cda:setId')">
          <xsl:text>urn:oid:</xsl:text>
          <xsl:value-of select="cda:setId/@root" />
        </xsl:when>
        <xsl:otherwise>
          <xsl:text>urn:uuid:</xsl:text>
          <xsl:value-of select="cda:setId/@root" />
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    
    <xsl:choose>
      <xsl:when test="cda:setId/@nullFlavor">
        <!-- TODO: ignore for now, add better handling later -->
      </xsl:when>
      <xsl:when test="cda:setId/@root and cda:setId/@extension and cda:versionNumber/@value">
        <xsl:element name="{$pElementName}">
          <system value="{$root-uri}" />
          <value value="{concat(cda:setId/@extension, '#', cda:versionNumber/@value)}" />
        </xsl:element>
      </xsl:when>
      <xsl:when test="cda:setId/@root and cda:setId/@extension">
        <xsl:element name="{$pElementName}">
          <system value="{$root-uri}" />
          <value value="{cda:setId/@extension}" />
        </xsl:element>
      </xsl:when>
      <xsl:when test="cda:setId/@root and not(cda:setId/@extension)">
        <xsl:element name="{$pElementName}">
          <system value="urn:ietf:rfc:3986" />
          <value value="{$root-uri}" />
        </xsl:element>
      </xsl:when>
    </xsl:choose>
    
  </xsl:template>
  
  
</xsl:stylesheet>
