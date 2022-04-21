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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns="urn:hl7-org:v3" xmlns:lcg="http://www.lantanagroup.com" xmlns:cda="urn:hl7-org:v3" xmlns:fhir="http://hl7.org/fhir"
  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:sdtc="urn:hl7-org:sdtc" version="2.0" exclude-result-prefixes="sdtc lcg xsl cda fhir">

  <xsl:import href="fhir2cda-TS.xslt" />
  <xsl:import href="fhir2cda-CD.xslt" />
  <xsl:import href="fhir2cda-utility.xslt" />

  <!-- ********************************************************************* -->
  <!-- Generic Procedure Processing                                        -->
  <!-- ********************************************************************* -->

  <!-- This is a FHIR Specimen that is going to be a Procedure in CDA-->
  <!-- These are contained in an Organizer -->
  <xsl:template match="fhir:Specimen" mode="component">
    <component>
      <xsl:call-template name="make-generic-procedure" />
    </component>
  </xsl:template>

  <!-- Named template: make-generic-procedure -->
  <xsl:template name="make-generic-procedure">

    <!-- templateId -->
    <procedure classCode="PROC" moodCode="EVN">
      <xsl:comment select="' [C-CDA] Specimen Collection Procedure (ID) '" />
      <templateId root="2.16.840.1.113883.10.20.22.4.315" extension="2018-09-01" />
      <code code="17636008" displayName="Specimen collection (procedure)" codeSystem="2.16.840.1.113883.6.96" codeSystemName="SNOMED CT" />
      <!-- Specimen collection date/time -->
      <xsl:apply-templates select="fhir:collection/fhir:collectedPeriod" />
      <xsl:apply-templates select="fhir:collection/fhir:collectedDateTime" />

      <!-- Specimen source -->
      <xsl:apply-templates select="fhir:collection/fhir:bodySite">
        <xsl:with-param name="pElementName" select="'targetSiteCode'" />
      </xsl:apply-templates>
      <xsl:if test="fhir:type">
        <xsl:comment select="' [C-CDA ID]  Specimen Participant (ID)  '" />
        <participant typeCode="PRD">
          <xsl:comment select="' [C-CDA ID] Specimen Participant (ID)  '" />
          <templateId root="2.16.840.1.113883.10.20.22.4.310" extension="2018-09-01" />
          <participantRole classCode="SPEC">
            <!-- Specimen id -->
            <xsl:choose>
              <xsl:when test="fhir:identifier">
                <xsl:apply-templates select="fhir:identifier" />
              </xsl:when>
              <xsl:otherwise>
                <id nullFlavor="NI" />
              </xsl:otherwise>
            </xsl:choose>
            <playingEntity>
              <!-- Specimen type -->
              <xsl:apply-templates select="fhir:type" />
            </playingEntity>
          </participantRole>
        </participant>
      </xsl:if>
    </procedure>
  </xsl:template>

</xsl:stylesheet>
