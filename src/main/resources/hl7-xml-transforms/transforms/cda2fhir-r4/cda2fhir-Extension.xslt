<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns="http://hl7.org/fhir" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:cda="urn:hl7-org:v3" xmlns:fhir="http://hl7.org/fhir" xmlns:sdtc="urn:hl7-org:sdtc"
  xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xhtml="http://www.w3.org/1999/xhtml" xmlns:lcg="http://www.lantanagroup.com"
   version="2.0" exclude-result-prefixes="lcg xsl cda fhir xs xsi sdtc xhtml">

  <xsl:import href="c-to-fhir-utility.xslt" />

  <!-- TEMPLATE: eICR Trigger Code extension
       Check to see if there is a @sdtc:valueSet value in the template - this should mean it's an eICR Trigger Code template -->
  <xsl:template
    match="cda:*/cda:code[@sdtc:valueSet] | cda:*/cda:code/cda:translation[@sdtc:valueSet] | cda:*/cda:value[@sdtc:valueSet] | cda:*/cda:value/cda:translation[@sdtc:valueSet] | cda:*/cda:consumable/cda:manufacturedProduct/cda:manufacturedMaterial/cda:code[@sdtc:valueSet] | cda:*/cda:consumable/cda:manufacturedProduct/cda:manufacturedMaterial/cda:code/cda:translation[@sdtc:valueSet]"
    mode="entry-extension">
    <!-- Make sure it is a template in eICR - there could potentially be other templates that use @sdtc:valueSet -->
    <xsl:if test="$gvCurrentIg = 'eICR'">
      <extension url="http://hl7.org/fhir/us/ecr/StructureDefinition/eicr-trigger-code-flag-extension">
        <extension url="triggerCodeValueSet">
          <xsl:variable name="vValueOid" select="concat('urn:oid:', @sdtc:valueSet)" />
          <valueOid value="{$vValueOid}" />
        </extension>
        <extension url="triggerCodeValueSetVersion">
          <valueString value="{@sdtc:valueSetVersion}" />
        </extension>
        <extension url="triggerCode">
          <xsl:apply-templates select=".">
            <xsl:with-param name="pElementName">valueCoding</xsl:with-param>
            <xsl:with-param name="includeCoding" select="false()" />
          </xsl:apply-templates>
        </extension>
      </extension>
    </xsl:if>
  </xsl:template>

  <!-- TEMPLATE: Address extension in eICR Travel History Observation profile -->
  <xsl:template match="cda:addr" mode="extension">
    <extension url="http://hl7.org/fhir/us/ecr/StructureDefinition/travel-history-address-extension">
      <xsl:apply-templates select=".">
        <xsl:with-param name="pElementName">valueAddress</xsl:with-param>
      </xsl:apply-templates>
    </extension>
  </xsl:template>
  
  <!-- TEMPLATE: Therapeutic Response to Medication Extension -->
  <xsl:template match="cda:entryRelationship/cda:observation[cda:templateId/@root='2.16.840.1.113883.10.20.15.2.3.37']" mode="extension">
    <extension url="http://hl7.org/fhir/us/ecr/StructureDefinition/therapeutic-medication-response-extension">
      <xsl:apply-templates select="cda:value">
        <xsl:with-param name="pElementName">valueCodeableConcept</xsl:with-param>
      </xsl:apply-templates>
    </extension>
  </xsl:template>

  <!-- TEMPLATE: Date determined extension (Pregnancy Status, Estimated Date of Delivery, Estimated Gestational Age of Pregnancy) -->
  <xsl:template match="cda:effectiveTime[parent::*[cda:templateId[@root = '2.16.840.1.113883.10.20.22.4.297' or @root = '2.16.840.1.113883.10.20.22.4.280']]] | cda:time[parent::cda:performer]" mode="extension">
    <extension url="http://hl7.org/fhir/us/ecr/StructureDefinition/date-determined-extension">
      <xsl:apply-templates select=".">
        <xsl:with-param name="pStartElementName">value</xsl:with-param>
      </xsl:apply-templates>
    </extension>
  </xsl:template>

  <!-- TEMPLATE: Date recorded extension (Pregnancy Status) -->
  <xsl:template match="cda:time[parent::cda:author]" mode="extension">
    <extension url="http://hl7.org/fhir/us/ecr/StructureDefinition/date-recorded-extension">
      <xsl:apply-templates select=".">
        <xsl:with-param name="pStartElementName">value</xsl:with-param>
      </xsl:apply-templates>
    </extension>
  </xsl:template>

  <!-- TEMPLATE: determination of reportability (RR PlanDefinition)-->
  <xsl:template match="cda:observation[cda:templateId[@root = '2.16.840.1.113883.10.20.15.2.3.19']]" mode="extension">
    <extension url="http://hl7.org/fhir/us/ecr/StructureDefinition/rr-determination-of-reportability-extension">
      <xsl:apply-templates select="cda:value">
        <xsl:with-param name="pElementName" select="'valueCodeableConcept'" />
      </xsl:apply-templates>
    </extension>
  </xsl:template>

  <!-- TEMPLATE: determination of reportability reason (RR PlanDefinition) -->
  <xsl:template match="cda:observation[cda:templateId/@root = '2.16.840.1.113883.10.20.15.2.3.26']" mode="extension">
    <extension url="http://hl7.org/fhir/us/ecr/StructureDefinition/rr-determination-of-reportability-reason-extension">
      <xsl:apply-templates select="cda:value[@xsi:type = 'ST']">
        <xsl:with-param name="pElementName" select="'valueString'" />
      </xsl:apply-templates>
      <xsl:apply-templates select="cda:value[@xsi:type = 'CD']">
        <xsl:with-param name="pElementName" select="'valueCodeableConcept'" />
      </xsl:apply-templates>
    </extension>
  </xsl:template>

  <!-- TEMPLATE: determination of reportability rule (RR PlanDefinition)-->
  <xsl:template match="cda:observation[cda:templateId/@root = '2.16.840.1.113883.10.20.15.2.3.27']" mode="extension">
    <extension url="http://hl7.org/fhir/us/ecr/StructureDefinition/rr-determination-of-reportability-rule-extension">
      <xsl:apply-templates select="cda:value[@xsi:type = 'ST']">
        <xsl:with-param name="pElementName" select="'valueString'" />
      </xsl:apply-templates>
    </extension>
  </xsl:template>

  <!-- TEMPLATE: rr-priority-extension -->
  <xsl:template match="//cda:observation[cda:templateId/@root = '2.16.840.1.113883.10.20.15.2.3.30']" mode="extension">
    <extension url="http://hl7.org/fhir/us/ecr/StructureDefinition/rr-priority-extension">
      <xsl:apply-templates select="cda:value">
        <xsl:with-param name="pElementName" select="'valueCodeableConcept'" />
      </xsl:apply-templates>
    </extension>
  </xsl:template>
  
  <!-- TEMPLATE: odh-Employer-extension -->
  <xsl:template match="cda:observation[cda:templateId/@root = '2.16.840.1.113883.10.20.22.4.217']/cda:participant[@typeCode='IND']" mode="extension">
    <extension url="http://hl7.org/fhir/us/odh/StructureDefinition/odh-Employer-extension">
      <valueReference>
        <xsl:apply-templates select="." mode="reference" />
<!--        <reference value="urn:uuid:{@lcg:uuid}" />-->
      </valueReference>
    </extension>
  </xsl:template>

  <!-- TEMPLATE: relates-to-extension (RR Communication) -->
  <xsl:template match="cda:ClinicalDocument[cda:templateId/@root = '2.16.840.1.113883.10.20.15.2.1.2']" mode="extension">
    <!-- First instance of this extension is the one with the CDA information (transforms) 
         Obviously this will always be here as we are transforming from CDA! -->
    <extension url="http://hl7.org/fhir/us/ecr/StructureDefinition/relates-to-extension">
      <extension url="type">
        <valueCode value="transforms" />
      </extension>
      <!-- CDA id -->
      <extension url="targetIdentifier">
        <xsl:apply-templates select="cda:id">
          <xsl:with-param name="pElementName" select="'valueIdentifier'" />
        </xsl:apply-templates>
      </extension>
      <!-- CDA setId (this is the same as the FHIR setId -->
      <xsl:if test="cda:setId">
        <extension url="setId">
          <xsl:apply-templates select="cda:setId">
            <xsl:with-param name="pElementName" select="'valueIdentifier'" />
          </xsl:apply-templates>
        </extension>
        <!-- CDA versionNumber (this is the same as the FHIR VersionNumber) 
             Can't have cda:versionNumber without cda:setId (or vv) -->
        <extension url="versionNumber">
          <!-- Just a string so no special processing needed -->
          <valueString value="{cda:versionNumber/@value}" />
        </extension>
      </xsl:if>
    </extension>

    <!-- replaces -->
    <!-- If the CDA versionNumber is > 1 and then this is replacing the CDA versionNumber - 1
         of the CDA document which should be in ClinicalDocument/relatedDocument/parentDocument otherwise 
         it's replacing nothing -->
    <xsl:if test="number(cda:versionNumber/@value) &gt; 1 and cda:relatedDocument[@typeCode = 'RPLC']/cda:parentDocument">
      <extension url="http://hl7.org/fhir/us/ecr/StructureDefinition/relates-to-extension">
        <extension url="type">
          <valueCode value="replaces" />
        </extension>
        <extension url="targetIdentifier">
          <xsl:apply-templates select="cda:relatedDocument/cda:parentDocument/cda:id">
            <xsl:with-param name="pElementName" select="'valueIdentifier'" />
          </xsl:apply-templates>
        </extension>
        <!-- setId -->
        <xsl:if test="cda:relatedDocument/cda:parentDocument/cda:setId">
          <extension url="setId">
            <xsl:apply-templates select="cda:relatedDocument/cda:parentDocument/cda:setId">
              <xsl:with-param name="pElementName" select="'valueIdentifier'" />
            </xsl:apply-templates>
          </extension>
          <!-- Can't have cda:versionNumber without cda:setId (or vv) -->
          <extension url="versionNumber">
            <!-- Just a string so no special processing needed -->
            <valueString value="{cda:relatedDocument/cda:parentDocument/cda:versionNumber/@value}" />
          </extension>
        </xsl:if>
      </extension>
    </xsl:if>

<!--    <!-\- FHIR setId and versionNumber information -\->
    <extension url="http://hl7.org/fhir/us/ecr/StructureDefinition/relates-to-extension">
      <!-\- CDA setId (this is the same as the FHIR setId -\->
      <!-\- If there isn't a setId and versionNumber in FHIR then we need to make one for FHIR -\->
      <xsl:variable name="vFHIRSetId">
        <xsl:choose>
          <xsl:when test="cda:setId">
            <xsl:value-of select="cda:setId" />
          </xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="cda:setId" />
          </xsl:otherwise>
        </xsl:choose>
        <xsl:if test="cda:setId">
          <extension url="setId">
            <xsl:apply-templates select="cda:setId">
              <xsl:with-param name="pElementName" select="'valueIdentifier'" />
            </xsl:apply-templates>
          </extension>
          <!-\- CDA versionNumber (this is the same as the FHIR VersionNumber) 
             Can't have cda:versionNumber without cda:setId (or vv) -\->
          <extension url="versionNumber">
            <!-\- Just a string so no special processing needed -\->
            <valueString value="{cda:versionNumber/@value}" />
          </extension>
        </xsl:if>
      </xsl:variable>
      <xsl:if test="cda:setId">
        <extension url="setId">
          <xsl:apply-templates select="cda:setId">
            <xsl:with-param name="pElementName" select="'valueIdentifier'" />
          </xsl:apply-templates>
        </extension>
        <!-\- CDA versionNumber (this is the same as the FHIR VersionNumber) 
             Can't have cda:versionNumber without cda:setId (or vv) -\->
        <extension url="versionNumber">
          <!-\- Just a string so no special processing needed -\->
          <valueString value="{cda:versionNumber/@value}" />
        </extension>
      </xsl:if>
    </extension>-->
  </xsl:template>

  <!-- Stop text printing out if there is no match -->
  <xsl:template match="text() | @*" mode="entry-extension">
    <xsl:apply-templates />
  </xsl:template>

</xsl:stylesheet>
