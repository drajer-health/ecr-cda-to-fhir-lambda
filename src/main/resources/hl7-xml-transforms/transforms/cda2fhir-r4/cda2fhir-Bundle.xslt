<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns="http://hl7.org/fhir" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:cda="urn:hl7-org:v3" xmlns:fhir="http://hl7.org/fhir" xmlns:sdtc="urn:hl7-org:sdtc"
  xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xhtml="http://www.w3.org/1999/xhtml" xmlns:lcg="http://www.lantanagroup.com" version="2.0"
  exclude-result-prefixes="lcg xsl cda fhir xs xsi sdtc xhtml">

  <xsl:import href="c-to-fhir-utility.xslt" />

  <xsl:template match="/" mode="convert">
    <!-- Adding parameter that uses global var so we can do unit testing properly -->
    <xsl:param name="pCurrentIg" as="xs:string" select="$gvCurrentIg"/>
    <Bundle>
      <!-- Generates an id that is unique for the node. It will always be the same for the same id. Should be unique across 
           documents as the CDA document id should be unique-->
      <id value="{concat($pCurrentIg, '-collection-bundle-', generate-id(cda:ClinicalDocument/cda:id))}" />

      <!-- Adding meta for eICR - needs to conform to eICR document bundle profile 
           **TODO** hard coding these for now - because the bundles are usually one level
           higher than the mapping in the template-profile-mapping.xml file
           but need to add in more scaleable solution -->
      <xsl:variable name="vBundleProfile" as="xs:string">
        <xsl:choose>
          <xsl:when test="$pCurrentIg = 'eICR'">
            <xsl:text>http://hl7.org/fhir/us/ecr/StructureDefinition/eicr-document-bundle</xsl:text>
          </xsl:when>
          <xsl:otherwise>
            <xsl:text />
          </xsl:otherwise>
        </xsl:choose>
      </xsl:variable>
      <xsl:if test="$vBundleProfile != ''">
        <meta>
          <profile value="{$vBundleProfile}" />
        </meta>
      </xsl:if>
      <identifier>
        <system value="urn:ietf:rfc:3986" />
        <value value="urn:uuid:{cda:ClinicalDocument/cda:id/@lcg:uuid}" />
      </identifier>
      <type>
        <xsl:attribute name="value">
          <xsl:choose>
            <!-- when RR, it is a Communication, which is a bundle collection -->
            <xsl:when test="$pCurrentIg = 'RR'">collection</xsl:when>
            <!-- otherwise it is a document, starting with a Composition -->
            <xsl:otherwise>document</xsl:otherwise>
          </xsl:choose>
        </xsl:attribute>
      </type>
      <timestamp>
        <xsl:attribute name="value">
          <xsl:value-of select="lcg:cdaTS2date(cda:ClinicalDocument/cda:effectiveTime/@value)" />
        </xsl:attribute>
      </timestamp>
      <xsl:apply-templates select="cda:ClinicalDocument" mode="bundle-entry" />

      <xsl:message>TODO: Add remaining header resources</xsl:message>

      <xsl:for-each select="//descendant::cda:entry">
        <xsl:apply-templates select="cda:*[not(@nullFlavor)]" mode="bundle-entry" />
      </xsl:for-each>

      <!-- Organization resources from participants of type LOC -->
      <xsl:for-each select="//descendant::cda:participant[@typeCode = 'LOC'][not(cda:participantRole/@classCode = 'TERR') and not(cda:participantRole/@classCode = 'SDLOC')][not(@nullFlavor)]">
        <xsl:apply-templates select="." mode="bundle-entry" />
      </xsl:for-each>
    </Bundle>
  </xsl:template>


</xsl:stylesheet>
