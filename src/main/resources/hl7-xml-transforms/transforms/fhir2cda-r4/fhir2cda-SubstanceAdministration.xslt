<?xml version="1.0" encoding="UTF-8"?>
<!-- 

Copyright 2020 Lantana Consulting Group

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

-->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns="urn:hl7-org:v3" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:lcg="http://www.lantanagroup.com"
   xmlns:cda="urn:hl7-org:v3" xmlns:fhir="http://hl7.org/fhir" exclude-result-prefixes="lcg xsl cda fhir" version="2.0">

  <xsl:import href="fhir2cda-CD.xslt" />
  <xsl:import href="fhir2cda-TS.xslt" />
  <xsl:import href="fhir2cda-utility.xslt" />

  <!-- fhir:MedicationDispense -> Medication Activity (cda:substanceAdministration) - entry -->
  <xsl:template match="fhir:MedicationDispense" mode="entry">
    <xsl:param name="generated-narrative">additional</xsl:param>
    <entry>
      <xsl:if test="$generated-narrative = 'generated'">
        <xsl:attribute name="typeCode">DRIV</xsl:attribute>
      </xsl:if>
      <xsl:call-template name="make-medication-activity">
        <xsl:with-param name="moodCode">INT</xsl:with-param>
      </xsl:call-template>
    </entry>
  </xsl:template>
  
  <!-- fhir:MedicationAdministration -> Medication Administration (cda:substanceAdministration)-->
  <xsl:template match="fhir:MedicationAdministration" mode="entry">
    <xsl:param name="generated-narrative">additional</xsl:param>
    <xsl:if test="$generated-narrative = 'generated'">
      <xsl:attribute name="typeCode">DRIV</xsl:attribute>
    </xsl:if>
    <entry>
      <xsl:call-template name="make-medication-administration" />
    </entry>
  </xsl:template>
  
  <!-- fhir:MedicationRequest: Medication Activity - entry -->
  <xsl:template match="fhir:MedicationRequest" mode="entry">
    <xsl:param name="generated-narrative">additional</xsl:param>
    <xsl:if test="$generated-narrative = 'generated'">
      <xsl:attribute name="typeCode">DRIV</xsl:attribute>
    </xsl:if>

    <entry>
      <xsl:call-template name="make-medication-activity">
        <xsl:with-param name="moodCode">INT</xsl:with-param>
      </xsl:call-template>
    </entry>
  </xsl:template>

  <!-- fhir:MedicationRequest: Medication Activity - entryRelationship -->
  <xsl:template match="fhir:MedicationRequest" mode="entry-relationship">
    <xsl:param name="typeCode" select="'COMP'" />
    <entryRelationship>
      <xsl:attribute name="typeCode" select="$typeCode" />
      <xsl:call-template name="make-medication-activity">
        <xsl:with-param name="moodCode">INT</xsl:with-param>
      </xsl:call-template>
    </entryRelationship>
  </xsl:template>

  <!-- fhir:Immunization: Immunization Activity - entry -->
  <xsl:template match="fhir:Immunization" mode="entry">
    <xsl:param name="generated-narrative">additional</xsl:param>
    <xsl:if test="$generated-narrative = 'generated'">
      <xsl:attribute name="typeCode">DRIV</xsl:attribute>
    </xsl:if>

    <entry>
      <xsl:call-template name="make-immunization-activity">
        <xsl:with-param name="moodCode">EVN</xsl:with-param>
      </xsl:call-template>
    </entry>
  </xsl:template>

  <!-- Create substanceAdministration: Immunization Activity -->
  <xsl:template name="make-immunization-activity">
    <xsl:param name="moodCode">EVN</xsl:param>

    <substanceAdministration classCode="SBADM" moodCode="{$moodCode}">
      <xsl:choose>
        <xsl:when test="fhir:status/@value = 'not-done'">
          <xsl:attribute name="negationInd" select="'true'" />
        </xsl:when>
        <xsl:otherwise>
          <xsl:attribute name="negationInd" select="'false'" />
        </xsl:otherwise>
      </xsl:choose>
      <!-- templateId -->
      <xsl:apply-templates select="." mode="map-resource-to-template" />
      <xsl:choose>
        <xsl:when test="fhir:identifier">
          <xsl:apply-templates select="fhir:identifier" />
        </xsl:when>
        <xsl:otherwise>
          <id nullFlavor="NI" />
        </xsl:otherwise>
      </xsl:choose>
      <xsl:choose>
        <xsl:when test="fhir:status">
          <xsl:apply-templates select="fhir:status" mode="medication-activity" />
        </xsl:when>
        <xsl:otherwise>
          <statusCode nullFlavor="NI" />
        </xsl:otherwise>
      </xsl:choose>
      <xsl:choose>
        <xsl:when test="fhir:occurrenceDateTime">
          <xsl:apply-templates select="fhir:occurrenceDateTime" />
        </xsl:when>
        <xsl:otherwise>
          <effectiveTime nullFlavor="NI" />
        </xsl:otherwise>
      </xsl:choose>
      <xsl:apply-templates select="fhir:route">
        <xsl:with-param name="pElementName" select="'routeCode'" />
      </xsl:apply-templates>
      <xsl:choose>
        <xsl:when test="fhir:doseQuantity">
          <xsl:apply-templates select="fhir:doseQuantity">
            <xsl:with-param name="pElementName" select="'doseQuantity'" />
            <xsl:with-param name="pIncludeDatatype" select="false()" />
          </xsl:apply-templates>
        </xsl:when>
        <xsl:otherwise>
          <doseQuantity nullFlavor="NI" />
        </xsl:otherwise>
      </xsl:choose>
      <consumable>
        <xsl:call-template name="make-immunization-medication-information" />
      </consumable>
    </substanceAdministration>
  </xsl:template>

  <!-- Create manufacturedProduct: Immunization Activity -->
  <xsl:template name="make-immunization-medication-information">

    <!-- Check to see if this is a trigger code template -->
    <xsl:variable name="vTriggerEntry">
      <xsl:call-template name="check-for-trigger" />
    </xsl:variable>
    <xsl:variable name="vTriggerExtension" select="$vTriggerEntry/fhir:extension" />

    <manufacturedProduct classCode="MANU">
      <!-- templateId -->
      <xsl:choose>
        <xsl:when test="$vTriggerExtension">
          <xsl:apply-templates select="." mode="map-trigger-resource-to-template" />
        </xsl:when>
        <xsl:otherwise>
          <xsl:apply-templates select="fhir:vaccineCode" mode="map-resource-to-template" />
        </xsl:otherwise>
      </xsl:choose>
      <manufacturedMaterial>
        <xsl:apply-templates select="fhir:vaccineCode">
          <xsl:with-param name="pTriggerExtension" select="$vTriggerExtension" />
        </xsl:apply-templates>
      </manufacturedMaterial>
    </manufacturedProduct>
  </xsl:template>

  <xsl:template name="make-medication-administration">
    <xsl:param name="moodCode">EVN</xsl:param>
    <substanceAdministration classCode="SBADM" moodCode="{$moodCode}">
      <!-- templateId -->
      <xsl:choose>
        <xsl:when test="$gvCurrentIg = 'PCP'">
          <templateId root="2.16.840.1.113883.10.20.37.3.10" extension="2017-08-01" />
          <templateId root="2.16.840.1.113883.10.20.22.4.16" extension="2014-06-09" />
        </xsl:when>
        <xsl:otherwise>
          <xsl:apply-templates select="." mode="map-resource-to-template" />
        </xsl:otherwise>
      </xsl:choose>
      <xsl:choose>
        <xsl:when test="fhir:identifier">
          <xsl:apply-templates select="fhir:identifier" />
        </xsl:when>
        <xsl:otherwise>
          <id nullFlavor="NI" />
        </xsl:otherwise>
      </xsl:choose>
      <xsl:choose>
        <xsl:when test="fhir:status">
          <xsl:apply-templates select="fhir:status" mode="medication-activity" />
        </xsl:when>
        <xsl:otherwise>
          <statusCode nullFlavor="NI" />
        </xsl:otherwise>
      </xsl:choose>

      <!-- effective timing -->
      <!-- TODO: xsi:type="IVL_TS and null-->
      <xsl:apply-templates select="fhir:effectiveDateTime">
        <xsl:with-param name="pXSIType" select="'IVL_TS'" />
        <xsl:with-param name="pOperator" select="'A'" />
      </xsl:apply-templates>
      <xsl:apply-templates select="fhir:effectivePeriod" >
        <xsl:with-param name="pXSIType" select="'IVL_TS'" />
      </xsl:apply-templates>

      <xsl:choose>
        <xsl:when test="fhir:dosage/fhir:route/fhir:coding">
          <xsl:apply-templates select="fhir:dosage/fhir:route">
            <xsl:with-param name="pElementName" select="'routeCode'" />
          </xsl:apply-templates>
        </xsl:when>
        <xsl:otherwise>
          <routeCode nullFlavor="NI" />
        </xsl:otherwise>
      </xsl:choose>
      <xsl:choose>
        <xsl:when test="fhir:dosage/fhir:dose">
          <xsl:apply-templates select="fhir:dosage/fhir:dose">
            <xsl:with-param name="pElementName" select="'doseQuantity'" />
            <xsl:with-param name="pIncludeDatatype" select="false()" />
          </xsl:apply-templates>
        </xsl:when>
        <xsl:otherwise>
          <doseQuantity nullFlavor="NI" />
        </xsl:otherwise>
      </xsl:choose>
      <consumable>
        <xsl:call-template name="make-medication-information" />
      </consumable>
      <xsl:for-each select="fhir:extension[@url = 'http://hl7.org/fhir/us/ecr/StructureDefinition/therapeutic-medication-response-extension']">

        <entryRelationship typeCode="CAUS">
          <observation classCode="OBS" moodCode="EVN">
            <xsl:comment select="' [eICR R2] Therapeutic Medication Response Observation '" />
            <templateId root="2.16.840.1.113883.10.20.15.2.3.37" extension="2019-04-01" />
            <id nullFlavor="NI" />
            <code code="67540-5" codeSystem="2.16.840.1.113883.6.1" codeSystemName="LOINC" displayName="Reponse to medication" />
            <statusCode code="completed" />
            <xsl:apply-templates select="../fhir:effectiveDateTime"/>
            <xsl:apply-templates select="fhir:valueCodeableConcept">
              <xsl:with-param name="pElementName" select="'value'"/>
              <xsl:with-param name="pXSIType" select="'CD'"/>
            </xsl:apply-templates>
          </observation>
        </entryRelationship>
      </xsl:for-each>
    </substanceAdministration>
  </xsl:template>

  <xsl:template name="make-medication-information">
    <!-- Check to see if this is a trigger code template -->
    <xsl:variable name="vTriggerEntry">
      <xsl:call-template name="check-for-trigger" />
    </xsl:variable>
    <xsl:variable name="vTriggerExtension" select="$vTriggerEntry/fhir:extension" />

    <manufacturedProduct classCode="MANU">
      <!-- templateId -->
      <xsl:choose>
        <xsl:when test="$vTriggerExtension">
          <xsl:apply-templates select="." mode="map-trigger-resource-to-template" />
        </xsl:when>
        <xsl:otherwise>
          <xsl:apply-templates select="fhir:medicationCodeableConcept" mode="map-resource-to-template" />
        </xsl:otherwise>
      </xsl:choose>
      <manufacturedMaterial>
        <xsl:apply-templates select="fhir:medicationCodeableConcept">
          <xsl:with-param name="pTriggerExtension" select="$vTriggerExtension" />
        </xsl:apply-templates>
      </manufacturedMaterial>
    </manufacturedProduct>
  </xsl:template>

  <xsl:template name="make-medication-activity">
    <xsl:param name="moodCode">EVN</xsl:param>
    <substanceAdministration classCode="SBADM" moodCode="{$moodCode}">
      <templateId root="2.16.840.1.113883.10.20.37.3.10" extension="2017-08-01" />
      <xsl:if test="$gvCurrentIg = 'PCP'">
        <templateId root="2.16.840.1.113883.10.20.22.4.16" extension="2014-06-09" />
      </xsl:if>
      <xsl:choose>
        <xsl:when test="fhir:identifier">
          <xsl:apply-templates select="fhir:identifier" />
        </xsl:when>
        <xsl:otherwise>
          <id nullFlavor="NI" />
        </xsl:otherwise>
      </xsl:choose>
      <xsl:if test="$gvCurrentIg = 'PCP'">
        <code code="16076005" codeSystem="2.16.840.1.113883.6.96" displayName="Prescription" />
      </xsl:if>
      <xsl:choose>
        <xsl:when test="fhir:status">
          <xsl:apply-templates select="fhir:status" mode="medication-activity" />
        </xsl:when>
        <xsl:otherwise>
          <statusCode nullFlavor="NI" />
        </xsl:otherwise>
      </xsl:choose>
      <xsl:choose>
        <xsl:when test="fhir:dosageInstruction/fhir:timing">
          <xsl:apply-templates select="fhir:dosageInstruction/fhir:timing" mode="medication-activity" />
        </xsl:when>
        <xsl:when test="fhir:authoredOn">
          <xsl:apply-templates select="fhir:authoredOn" mode="medication-activity" />
        </xsl:when>
        <xsl:otherwise>
          <effectiveTime xsi:type="IVL_TS" nullFlavor="NI" />
        </xsl:otherwise>
      </xsl:choose>
      <xsl:choose>
        <xsl:when test="fhir:dosageInstruction/fhir:doseQuantity/fhir:value/@value">
          <doseQuantity value="{fhir:dosageInstruction/fhir:doseQuantity/fhir:value/@value}" />
        </xsl:when>
        <xsl:otherwise>
          <doseQuantity nullFlavor="NI" />
        </xsl:otherwise>
      </xsl:choose>
      <xsl:for-each select="fhir:medicationCodeableConcept">
        <consumable>
          <manufacturedProduct classCode="MANU">
            <!-- [C-CDA R2.0] Medication information (V2) -->
            <templateId root="2.16.840.1.113883.10.20.22.4.23" extension="2014-06-09" />
            <id root="4b355395-790c-405d-826f-f5a8e242db89" />
            <manufacturedMaterial>
              <xsl:call-template name="CodeableConcept2CD" />
            </manufacturedMaterial>
          </manufacturedProduct>
        </consumable>
      </xsl:for-each>
    </substanceAdministration>
  </xsl:template>

  <xsl:template match="fhir:status" mode="medication-activity">
    <statusCode>
      <xsl:choose>
        <xsl:when test="@value = 'active'">
          <xsl:attribute name="code">active</xsl:attribute>
        </xsl:when>
        <xsl:when test="@value = 'completed'">
          <xsl:attribute name="code">completed</xsl:attribute>
        </xsl:when>
        <xsl:when test="@value = 'cancelled'">
          <xsl:attribute name="code">cancelled</xsl:attribute>
        </xsl:when>
        <xsl:when test="@value = 'unknown'">
          <xsl:attribute name="nullFlavor">UNK</xsl:attribute>
        </xsl:when>
        <xsl:otherwise>
          <xsl:attribute name="nullFlavor">OTH</xsl:attribute>
        </xsl:otherwise>
      </xsl:choose>
    </statusCode>
  </xsl:template>

  <xsl:template match="fhir:timing" mode="medication-activity">
    <xsl:for-each select="fhir:event">
      <effectiveTime>
        <xsl:attribute name="value">
          <xsl:call-template name="Date2TS">
            <xsl:with-param name="date" select="@value" />
            <xsl:with-param name="includeTime" select="true()" />
          </xsl:call-template>
        </xsl:attribute>
      </effectiveTime>
    </xsl:for-each>
    <xsl:for-each select="fhir:repeat">
      <xsl:choose>
        <xsl:when test="fhir:boundsPeriod">
          <xsl:for-each select="fhir:boundsPeriod">
            <effectiveTime xsi:type="IVL_TS">
              <low>
                <xsl:attribute name="value">
                  <xsl:call-template name="Date2TS">
                    <xsl:with-param name="date" select="fhir:start/@value" />
                    <xsl:with-param name="includeTime" select="true()" />
                  </xsl:call-template>
                </xsl:attribute>
              </low>
              <high>
                <xsl:attribute name="value">
                  <xsl:call-template name="Date2TS">
                    <xsl:with-param name="date" select="fhir:end/@value" />
                    <xsl:with-param name="includeTime" select="true()" />
                  </xsl:call-template>
                </xsl:attribute>
              </high>
            </effectiveTime>
          </xsl:for-each>

        </xsl:when>
        <xsl:otherwise>
          <effectiveTime xsi:type="IVL_TS">
            <low nullFlavor="NI" />
          </effectiveTime>
        </xsl:otherwise>
      </xsl:choose>
      <xsl:if test="fhir:period and fhir:periodUnit">
        <effectiveTime xsi:type="PIVL_TS" operator="A">
          <period xsi:type="PQ" value="{fhir:period/@value}" unit="{fhir:periodUnit/@value}" />
        </effectiveTime>
      </xsl:if>
    </xsl:for-each>
  </xsl:template>

  <xsl:template match="fhir:authoredOn" mode="medication-activity">
    <effectiveTime xsi:type="IVL_TS">
      <low>
        <xsl:attribute name="value">
          <xsl:call-template name="Date2TS">
            <xsl:with-param name="date" select="@value" />
            <xsl:with-param name="includeTime" select="true()" />
          </xsl:call-template>
        </xsl:attribute>
      </low>
      <high>
        <xsl:attribute name="value">
          <xsl:call-template name="Date2TS">
            <xsl:with-param name="date" select="@value" />
            <xsl:with-param name="includeTime" select="true()" />
          </xsl:call-template>
        </xsl:attribute>
      </high>
    </effectiveTime>
  </xsl:template>

</xsl:stylesheet>
