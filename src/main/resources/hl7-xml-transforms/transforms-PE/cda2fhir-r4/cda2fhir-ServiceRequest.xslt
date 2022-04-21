<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns="http://hl7.org/fhir" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:cda="urn:hl7-org:v3" xmlns:fhir="http://hl7.org/fhir" xmlns:sdtc="urn:hl7-org:sdtc"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xhtml="http://www.w3.org/1999/xhtml"
    xmlns:lcg="http://www.lantanagroup.com"
    exclude-result-prefixes="lcg xsl cda fhir xs xsi sdtc xhtml" version="2.0">

    <xsl:import href="c-to-fhir-utility.xslt"/>

    <xsl:template
      match="cda:act[cda:templateId[@root = '2.16.840.1.113883.10.20.22.4.140']] | cda:act[@moodCode = 'INT'][cda:templateId[@root = '2.16.840.1.113883.10.20.22.4.12'][@extension = '2014-06-09']] | cda:observation[@moodCode = 'RQO'][cda:templateId[@root = '2.16.840.1.113883.10.20.15.2.3.4']]"
        mode="bundle-entry">
        <xsl:call-template name="create-bundle-entry"/>
        <xsl:apply-templates select="cda:author" mode="bundle-entry"/>
        <xsl:apply-templates select="cda:performer" mode="bundle-entry"/>
    </xsl:template>


    <xsl:template
      match="cda:act[cda:templateId[@root = '2.16.840.1.113883.10.20.22.4.140']] | cda:act[@moodCode = 'INT'][cda:templateId[@root = '2.16.840.1.113883.10.20.22.4.12'][@extension = '2014-06-09']] | cda:observation[@moodCode = 'RQO'][cda:templateId[@root = '2.16.840.1.113883.10.20.15.2.3.4']]">
        <ServiceRequest xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
            xmlns="http://hl7.org/fhir">
            <xsl:call-template name="add-meta" />
            <xsl:apply-templates select="cda:id"/>
            <status value="{cda:statusCode/@code}"/>
            <xsl:choose>
                <xsl:when test="@moodCode = 'INT'">
                    <intent value="plan"/>
                </xsl:when>
                <xsl:when test="@moodCode = 'RQO'">
                    <intent value="order"/>
                </xsl:when>
            </xsl:choose>
            <xsl:apply-templates select="cda:code" mode="procedure-request"/>
            <xsl:call-template name="subject-reference"/>
            <xsl:if test="cda:effectiveTime/@value">
                <occurrenceDateTime value="{lcg:cdaTS2date(cda:effectiveTime/@value)}"/>
            </xsl:if>
            <xsl:if test="cda:author">
                <xsl:call-template name="author-reference">
                    <xsl:with-param name="pElementName">requester</xsl:with-param>
                </xsl:call-template>
            </xsl:if>
        </ServiceRequest>
    </xsl:template>

    <xsl:template match="cda:code" mode="procedure-request">
        <xsl:call-template name="newCreateCodableConcept">
            <xsl:with-param name="pElementName">code</xsl:with-param>
        </xsl:call-template>
    </xsl:template>
</xsl:stylesheet>
