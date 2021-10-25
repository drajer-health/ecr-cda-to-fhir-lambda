<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns="http://hl7.org/fhir" 
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:cda="urn:hl7-org:v3" 
    xmlns:fhir="http://hl7.org/fhir" 
    xmlns:sdtc="urn:hl7-org:sdtc"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" 
    xmlns:xhtml="http://www.w3.org/1999/xhtml"
    xmlns:lcg="http://www.lantanagroup.com"
    exclude-result-prefixes="lcg xsl cda fhir xs xsi sdtc xhtml"
    version="2.0">

    <!-- This file matches on Coverage activities, but removes that wrapper and iterates over the Policy activies instead, since Coverage activity adds nothing from the FHIR perspective --> 

    <xsl:template
        match="cda:act[cda:templateId[@root = '2.16.840.1.113883.10.20.22.4.60']]"
        mode="bundle-entry">
        <xsl:for-each select="cda:entryRelationship/cda:act[cda:templateId[@root = '2.16.840.1.113883.10.20.22.4.61']]">
            <xsl:call-template name="create-bundle-entry"/>
            <xsl:for-each select="cda:performer[cda:templateId[@root = '2.16.840.1.113883.10.20.22.4.87']]/cda:assignedEntity[cda:code[@code = 'PAYOR']]">
                <xsl:call-template name="create-payor-org-entry"/>
            </xsl:for-each>
            <xsl:for-each select="cda:participant[@typeCode= 'HLD']">
                <xsl:call-template name="create-bundle-entry"/>
            </xsl:for-each>
        </xsl:for-each>
    </xsl:template>
    
    <xsl:template name="create-payor-org-entry">
        <entry>
            <fullUrl value="urn:uuid:{@lcg:uuid}"/>
            <resource>
                <xsl:apply-templates select="." mode="payor"/>
            </resource>
        </entry>
    </xsl:template>
    
    
    <xsl:template
        match="cda:act[cda:templateId[@root = '2.16.840.1.113883.10.20.22.4.60']]"
        mode="reference">
        <xsl:param name="wrapping-elements"/>
        <xsl:for-each select="cda:entryRelationship/cda:act[cda:templateId[@root = '2.16.840.1.113883.10.20.22.4.61']]">
            <xsl:apply-templates select="." mode="reference">
            	<xsl:with-param name="wrapping-elements" select="$wrapping-elements"/>
            </xsl:apply-templates>
        </xsl:for-each>
    </xsl:template>
	

    <xsl:template
        match="cda:act[cda:templateId[@root = '2.16.840.1.113883.10.20.22.4.61']]">
        <Coverage>
            <xsl:call-template name="add-meta" />
            <xsl:apply-templates select="cda:id"/>
            <status value="active"/>
            <xsl:apply-templates select="cda:code">
                <xsl:with-param name="pElementName">type</xsl:with-param>
            </xsl:apply-templates>
            
            <xsl:if test="cda:participant[@typeCode= 'HLD']">
                <policyHolder>
                    <xsl:apply-templates select="cda:participant[@typeCode= 'HLD']" mode="reference"/>
                </policyHolder>
            </xsl:if>

            <!--
            <xsl:call-template name="subject-reference">
                <xsl:with-param name="pElementName">subscriber</xsl:with-param>
            </xsl:call-template>
            <xsl:if test="cda:participant[cda:templateId[@root = '2.16.840.1.113883.10.20.22.4.89']]">
                <subscriberId value="urn:hl7ii:{cda:participant[cda:templateId[@root = '2.16.840.1.113883.10.20.22.4.89']]
                    /cda:participantRole/cda:id/@root}:{cda:participant[cda:templateId[@root = '2.16.840.1.113883.10.20.22.4.89']]
                    /cda:participantRole/cda:id/@extension}"/>
            </xsl:if>
            -->
            <xsl:call-template name="subject-reference">
                <xsl:with-param name="pElementName">beneficiary</xsl:with-param>
            </xsl:call-template>
            <xsl:if test="cda:performer[cda:templateId[@root = '2.16.840.1.113883.10.20.22.4.87']]
                [cda:assignedEntity[cda:code[@code = 'PAYOR']]]">
                <payor>
                    <xsl:apply-templates select="cda:performer[cda:templateId[@root = '2.16.840.1.113883.10.20.22.4.87']]/cda:assignedEntity[cda:code[@code = 'PAYOR']]" mode="reference"/>
                </payor>
            </xsl:if>
        </Coverage>
    </xsl:template>
    
   
    <xsl:template match="cda:performer[cda:templateId[@root = '2.16.840.1.113883.10.20.22.4.87']]/cda:assignedEntity[cda:code[@code = 'PAYOR']]" mode="payor">
        <Organization>
            <xsl:apply-templates select="cda:id"/>
            <xsl:apply-templates select="cda:code">
                <xsl:with-param name="pElementName">type</xsl:with-param>
            </xsl:apply-templates>
            <xsl:if test="cda:representedOrganization/cda:name">
                <name>
                    <xsl:attribute name="value">
                        <xsl:value-of select="cda:representedOrganization/cda:name"/>
                    </xsl:attribute>
                </name>
            </xsl:if>
            <xsl:apply-templates select="cda:telecom"/>
            <xsl:apply-templates select="cda:addr"/>
        </Organization>
    </xsl:template>
   
    
    
</xsl:stylesheet>
