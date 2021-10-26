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
  <!-- Generic Observation Processing                                        -->

  <!-- There are 3 different options (modes) for processing Observations:
        - entry (contained in a section)
        - entryRelationship (contained in another ClinicalStatement)
        - component (contained in an Organizer)
       Observations from FHIR can have contained hasMember elements: these
       will become Organizers in CDA                                         -->
  <!-- ********************************************************************* -->

  <!-- Generic Observation entry (no contained hasMember - if contained hasMember then Organizer)-->
  <!-- These are contained in a Section-->
  <xsl:template match="fhir:Observation[count(fhir:hasMember) = 0][not(fhir:category/fhir:coding[fhir:code/@value = 'laboratory'])]" mode="entry">
    <xsl:param name="generated-narrative">additional</xsl:param>
    <entry>
      <xsl:if test="$generated-narrative = 'generated'">
        <xsl:attribute name="typeCode">DRIV</xsl:attribute>
      </xsl:if>
      <xsl:choose>
        <!-- Vital Signs -->
        <xsl:when test="fhir:category/fhir:coding[fhir:system/@value = 'http://terminology.hl7.org/CodeSystem/observation-category']/fhir:code/@value = 'vital-signs'">
          <xsl:choose>
            <!-- PCP creates the vital signs in a Health Concern -->
            <xsl:when test="$gvCurrentIg = 'PCP'">
              <xsl:call-template name="make-vitalsign-in-health-concern" />
            </xsl:when>
            <!-- All others are going to be standalone inside an Organizer -->
            <xsl:otherwise>
              <xsl:call-template name="make-vitalsign" />
            </xsl:otherwise>
          </xsl:choose>
        </xsl:when>
        <!-- Everything other than Vital Signs -->
        <xsl:otherwise>
          <xsl:call-template name="make-generic-observation" />
        </xsl:otherwise>
      </xsl:choose>
    </entry>
  </xsl:template>

  <!-- Generic Observation entryRelationship (no contained hasMember - if contained hasMember then Organizer)-->
  <!-- These are contained in another ClinicalStatement -->
  <xsl:template match="fhir:Observation[count(fhir:hasMember) = 0]" mode="entry-relationship">
    <xsl:param name="pTypeCode" select="'COMP'" />
    <entryRelationship typeCode="{$pTypeCode}">
      <xsl:call-template name="make-generic-observation" />
    </entryRelationship>
  </xsl:template>

  <!-- Generic Observation component (no contained hasMember - if contained hasMember then Organizer)-->
  <!-- These are contained in an Organizer -->
  <xsl:template match="fhir:Observation[count(fhir:hasMember) = 0]" mode="component">
    <component>
      <xsl:choose>
        <xsl:when test="fhir:category/fhir:coding[fhir:system/@value = 'http://terminology.hl7.org/CodeSystem/observation-category']/fhir:code/@value = 'vital-signs'">
          <xsl:call-template name="make-vitalsign" />
        </xsl:when>
        <xsl:otherwise>
          <xsl:call-template name="make-generic-observation" />
        </xsl:otherwise>
      </xsl:choose>
    </component>
  </xsl:template>

  <!-- Generic Component -->
  <xsl:template match="fhir:component">
    <observation classCode="OBS" moodCode="EVN">
      <!-- templateId -->
      <xsl:call-template name="get-template-id" />
      <!-- id -->
      <!-- Components don't have an id -->
      <id nullFlavor="NI" />
      <!-- code -->
      <xsl:apply-templates select="fhir:code" />
      <!-- statusCode -->
      <statusCode code="completed" />
      <xsl:choose>
        <xsl:when test="fhir:extension[@url = 'http://hl7.org/fhir/us/ecr/StructureDefinition/date-determined-extension']">
          <xsl:apply-templates select="fhir:extension[@url = 'http://hl7.org/fhir/us/ecr/StructureDefinition/date-determined-extension']/fhir:valueDateTime" />
        </xsl:when>
        <xsl:otherwise>
          <effectiveTime nullFlavor="NI" />
        </xsl:otherwise>
      </xsl:choose>
      <!-- value -->
      <xsl:for-each select="fhir:valueCodeableConcept">
        <xsl:apply-templates select=".">
          <xsl:with-param name="pElementName" select="'value'" />
          <xsl:with-param name="pXSIType" select="'CD'" />
        </xsl:apply-templates>
      </xsl:for-each>
      <xsl:for-each select="fhir:valueString">
        <value xsi:type="ST">
          <xsl:value-of select="@value" />
        </value>
      </xsl:for-each>
      <xsl:apply-templates select="fhir:valueQuantity" />
      <xsl:apply-templates select="fhir:valueDateTime">
        <xsl:with-param name="pElementName" select="'value'" />
        <xsl:with-param name="pXSIType" select="'TS'" />
      </xsl:apply-templates>
      <!-- interpretationCode -->
      <xsl:for-each select="fhir:interpretation">
        <xsl:call-template name="CodeableConcept2CD">
          <xsl:with-param name="pElementName">interpretationCode</xsl:with-param>
        </xsl:call-template>
      </xsl:for-each>
      <xsl:for-each select="fhir:component">
        <entryRelationship> </entryRelationship>
      </xsl:for-each>
      <!-- reference -->
    </observation>
  </xsl:template>

  <!-- Named template: make-generic-observation -->
  <!-- This should cover most cases - there are still missing elements, but
       add them as we need them 
       Need to refactor - too big! -->
  <xsl:template name="make-generic-observation">

    <!-- Check to see if this is a trigger code template -->
    <xsl:variable name="vTriggerEntry">
      <xsl:call-template name="check-for-trigger" />
    </xsl:variable>
    <xsl:variable name="vTriggerExtension" select="$vTriggerEntry/fhir:extension" />

    <observation classCode="OBS" moodCode="EVN">
      <!-- templateId -->
      <xsl:call-template name="get-template-id">
        <xsl:with-param name="pTriggerExtension" select="$vTriggerExtension" />
      </xsl:call-template>

      <!-- id -->
      <xsl:call-template name="get-id" />

      <!-- code -->
      <!-- Catch any templates that need to be assertions -->
      <xsl:choose>
        <!-- Pregnancy, add others as needed -->
        <xsl:when test="fhir:code/fhir:coding/fhir:code/@value = '82810-3'">
          <code code="ASSERTION" codeSystem="2.16.840.1.113883.5.4" />
        </xsl:when>
        <xsl:otherwise>
          <xsl:apply-templates select="fhir:code">
            <xsl:with-param name="pTriggerExtension" select="$vTriggerExtension" />
          </xsl:apply-templates>
        </xsl:otherwise>
      </xsl:choose>
      <!-- negationInd -->
      <!-- derivationExpr -->
      <!-- text -->
      <!-- statusCode -->
      <xsl:apply-templates select="fhir:status" />
      <!-- effectiveTime -->
      <xsl:choose>
        <xsl:when test="fhir:effectiveDateTime | fhir:effectivePeriod | fhir:effectiveTime | fhir:effectiveInstant">
          <xsl:apply-templates select="fhir:effectiveDateTime | fhir:effectivePeriod | fhir:effectiveTime | fhir:effectiveInstant" />
        </xsl:when>
        <xsl:otherwise>
          <effectiveTime nullFlavor="NI" />
        </xsl:otherwise>
      </xsl:choose>
      <!-- priorityCode -->
      <!-- repeatNumber -->
      <!-- languageCode -->
      <!-- value -->
      <xsl:for-each select="fhir:valueCodeableConcept">
        <xsl:apply-templates select=".">
          <xsl:with-param name="pElementName" select="'value'" />
          <xsl:with-param name="pXSIType" select="'CD'" />
          <xsl:with-param name="pTriggerExtension" select="$vTriggerExtension" />
        </xsl:apply-templates>
      </xsl:for-each>
      <xsl:for-each select="fhir:valueString">
        <value xsi:type="ST">
          <xsl:value-of select="@value" />
        </value>
      </xsl:for-each>
      <xsl:apply-templates select="fhir:valueQuantity" />
      <xsl:apply-templates select="fhir:valueDateTime">
        <xsl:with-param name="pElementName" select="'value'" />
        <xsl:with-param name="pXSIType" select="'TS'" />
      </xsl:apply-templates>
      <!-- interpretationCode -->
      <xsl:for-each select="fhir:interpretation">
        <xsl:call-template name="CodeableConcept2CD">
          <xsl:with-param name="pElementName">interpretationCode</xsl:with-param>
        </xsl:call-template>
      </xsl:for-each>
      <!-- methodCode -->
      <xsl:apply-templates select="fhir:method">
        <xsl:with-param name="pElementName" select="'methodCode'" />
      </xsl:apply-templates>
      <!-- targetSiteCode -->
      <!-- referenceRange -->
      <xsl:for-each select="fhir:referenceRange">
        <xsl:call-template name="get-reference-range" />
      </xsl:for-each>
      <!-- precondition -->
      <!-- performer -->
      <xsl:for-each select="fhir:extension[@url = 'http://hl7.org/fhir/us/ecr/StructureDefinition/date-determined-extension']">
        <perfomer>
          <xsl:comment select="' Pregnancy Status Determination Date '" />
          <xsl:apply-templates select="fhir:valueDateTime">
            <xsl:with-param name="pElementName" select="'time'" />
          </xsl:apply-templates>
          <assignedEntity>
            <id nullFlavor="NA" />
          </assignedEntity>
        </perfomer>
      </xsl:for-each>
      <!-- author -->
      <xsl:for-each select="fhir:extension[@url = 'http://hl7.org/fhir/us/ecr/StructureDefinition/date-recorded-extension']">
        <author>
          <xsl:comment select="' Pregnancy Status Recorded Date '" />
          <xsl:apply-templates select="fhir:valueDateTime">
            <xsl:with-param name="pElementName" select="'time'" />
          </xsl:apply-templates>
          <assignedAuthor>
            <id nullFlavor="NA" />
          </assignedAuthor>
        </author>
      </xsl:for-each>
      <!-- informant -->
      <!-- subject -->
      <!-- specimen -->
      <!-- participant -->
      <xsl:for-each select="fhir:extension[@url = 'http://hl7.org/fhir/us/odh/StructureDefinition/odh-Employer-extension']/fhir:valueReference">
        <!-- Put the Organization into a variable -->
        <xsl:variable name="referenceURI">
          <xsl:call-template name="resolve-to-full-url">
            <xsl:with-param name="referenceURI" select="fhir:reference/@value" />
          </xsl:call-template>
        </xsl:variable>
        <xsl:variable name="vOrganization" select="//fhir:entry[fhir:fullUrl/@value = $referenceURI]/fhir:resource/fhir:*" />
        <participant typeCode="IND">
          <participantRole classCode="ROL">
            <!-- id -->
            <xsl:call-template name="get-id" />
            <xsl:apply-templates select="$vOrganization/fhir:address" />
            <xsl:apply-templates select="$vOrganization/fhir:telecom" />
            <playingEntity>
              <xsl:apply-templates select="$vOrganization/fhir:name" mode="data-type-ON" />
            </playingEntity>
          </participantRole>
        </participant>
      </xsl:for-each>
      <!-- entryRelationship (ignore birth order) -->
      <xsl:for-each select="fhir:component[not(fhir:code/fhir:coding/fhir:code/@value = '73771-8')]">
        <entryRelationship>
          <xsl:choose>
            <!-- These 3 ODH componenents are REFR - going to make the default COMP -->
            <xsl:when test="fhir:code/fhir:coding/fhir:code/@value = '87729-0' or fhir:code/fhir:coding/fhir:code/@value = '86188-0' or fhir:code/fhir:coding/fhir:code/@value = '21844-6'">
              <xsl:attribute name="typeCode" select="'REFR'" />
            </xsl:when>
            <xsl:otherwise>
              <xsl:attribute name="typeCode" select="'COMP'" />
            </xsl:otherwise>
          </xsl:choose>
          <xsl:apply-templates select="." />
        </entryRelationship>
      </xsl:for-each>
      <!-- If this is eICR and this is a Result Observation Trigger Code template -->
      <xsl:if test="$vTriggerExtension and fhir:category/fhir:coding[fhir:system/@value = 'http://terminology.hl7.org/CodeSystem/observation-category']/fhir:code/@value = 'laboratory'">
        <entryRelationship typeCode="COMP">
          <observation classCode="OBS" moodCode="EVN">
            <xsl:comment select="' [C-CDA ID] Laboratory Observation Result Status (ID) '" />
            <templateId root="2.16.840.1.113883.10.20.22.4.419" extension="2018-09-01" />
            <code code="92236-9" displayName="Laboratory Observation Result Status" codeSystemName="LOINC" codeSystem="2.16.840.1.113883.6.1" />
            <xsl:apply-templates select="fhir:status" mode="map-lab-obs-status" />
          </observation>
        </entryRelationship>
      </xsl:if>
      <!-- If this is a Pregnancy Observation add a matching Pregnancy Outcome Observation -->
      <xsl:if test="fhir:meta/fhir:profile/@value = 'http://hl7.org/fhir/us/ecr/StructureDefinition/pregnancy-status-observation'">
        <xsl:variable name="vPregnancyStatusFullUrl" select="../../fhir:fullUrl/@value" />
        <xsl:for-each select="//fhir:Observation[fhir:meta/fhir:profile/@value = 'http://hl7.org/fhir/us/ecr/StructureDefinition/pregnancy-outcome-observation']">
          <xsl:variable name="vRelatedPregnancyStatusFullUrl" select="fhir:focus/fhir:reference/@value" />
          <xsl:if test="$vPregnancyStatusFullUrl = $vRelatedPregnancyStatusFullUrl">
            <entryRelationship typeCode="COMP">
              <sequenceNumber value="{fhir:component[fhir:code/fhir:coding/fhir:code/@value='73771-8']/fhir:valueInteger/@value}" />
              <xsl:call-template name="make-generic-observation" />
            </entryRelationship>
          </xsl:if>
        </xsl:for-each>
      </xsl:if>
      <!-- reference -->
    </observation>
  </xsl:template>

  <!-- Generic Questionnaire Item Observation -->
  <xsl:template
    match="fhir:item[fhir:linkId/@value = ('risk-factor-birth-weight', 'risk-factor-gestational-age', 'inborn-outborn-observation', 'criteria-used', 'died', 'los-contributed-to-death')][fhir:answer]">
    <xsl:variable name="vLinkId" select="fhir:linkId/@value" />
    <observation classCode="OBS" moodCode="EVN">
      <!-- @negationInd -->
      <xsl:attribute name="negationInd" select="'false'" />
      <!-- templateId -->
      <xsl:call-template name="get-template-id" />
      <id nullFlavor="NA" />
      <code>
        <xsl:apply-templates select="$gvHaiQuestionnaire/fhir:Questionnaire//fhir:item[fhir:linkId/@value = $vLinkId]/fhir:code" />
      </code>
      <statusCode code="completed" />
      <effectiveTime nullFlavor="NA" />
      <xsl:apply-templates select="fhir:answer" />
    </observation>
  </xsl:template>

  <!-- Assertion Pattern Questionnaire Item Observation -->
  <xsl:template match="fhir:item[fhir:linkId/@value = ('risk-factor-central-line', 'event-type')][fhir:answer]">
    <xsl:variable name="vLinkId" select="fhir:linkId/@value" />
    <observation classCode="OBS" moodCode="EVN">
      <!-- @negationInd -->
      <xsl:choose>
        <xsl:when test="fhir:answer/fhir:valueBoolean/@value = 'true'">
          <xsl:attribute name="negationInd" select="'false'" />
        </xsl:when>
        <xsl:when test="fhir:answer/fhir:valueBoolean/@value = 'false'">
          <xsl:attribute name="negationInd" select="'true'" />
        </xsl:when>
      </xsl:choose>
      <!-- templateId -->
      <xsl:call-template name="get-template-id" />
      <!-- id -->
      <xsl:choose>
        <xsl:when test="$vLinkId = ('event-type')">
          <xsl:call-template name="get-id">
            <xsl:with-param name="pNoNullAllowed" select="true()" />
          </xsl:call-template>
        </xsl:when>
        <xsl:otherwise>
          <id nullFlavor="NA" />
        </xsl:otherwise>
      </xsl:choose>
      <code codeSystem="2.16.840.1.113883.5.4" code="ASSERTION" />
      <statusCode code="completed" />
      <effectiveTime nullFlavor="NA" />
      <xsl:choose>
        <xsl:when test="$vLinkId = ('event-type')">
          <xsl:apply-templates select="fhir:answer" />
        </xsl:when>
        <xsl:otherwise>
          <value xsi:type="CD">
            <xsl:apply-templates select="$gvHaiQuestionnaire/fhir:Questionnaire//fhir:item[fhir:linkId/@value = $vLinkId]/fhir:code" />
          </value>
        </xsl:otherwise>
      </xsl:choose>

    </observation>
  </xsl:template>

  <!-- ********************************************************************* -->
  <!-- Suppress Questionnaire Item Processing                                -->
  <!-- ********************************************************************* -->
  <xsl:template match="fhir:item[fhir:linkId/@value = 'gestational-age-known'][fhir:answer/fhir:valueBoolean/@value = 'true']" />

  <!-- Suppress item discharge-date - used in EncompassingEncounter -->
  <xsl:template match="fhir:item[fhir:linkId/@value = 'discharge-date']" />

  <!-- ********************************************************************* -->
  <!-- Specific Observation Processing                                       -->
  <!-- ********************************************************************* -->


  <xsl:template match="fhir:item[fhir:linkId/@value = 'gestational-age-known'][fhir:answer/fhir:valueBoolean/@value = 'false']">
    <!-- Special processing for this item - if this item is false then the next item (risk-factor-gestational-age) is not enabled
         But if this is false, then the Gestataional Age at Birth template needs to be created wtih a value/@nullFlavor='UNK'
         So we are going to set our linkId='risk-factor-gestational-age' and build that template-->
    <xsl:variable name="vLinkId" select="'risk-factor-gestational-age'" />
    <observation classCode="OBS" moodCode="EVN">
      <xsl:attribute name="negationInd" select="'false'" />
      <!-- templateId -->
      <xsl:call-template name="get-template-id" />
      <id nullFlavor="NA" />
      <code>
        <xsl:apply-templates select="$gvHaiQuestionnaire/fhir:Questionnaire//fhir:item[fhir:linkId/@value = $vLinkId]/fhir:code" />
      </code>
      <statusCode code="completed" />
      <code nullFlavor="UNK" />
    </observation>
  </xsl:template>

  <!-- fhir:extension[@url = 'http://hl7.org/fhir/us/ecr/StructureDefinition/rr-priority-extension'] -> Reportability Response Priority (Observation) -->
  <xsl:template match="fhir:extension[@url = 'http://hl7.org/fhir/us/ecr/StructureDefinition/rr-priority-extension']">
    <entry typeCode="DRIV">
      <observation classCode="OBS" moodCode="EVN">
        <xsl:call-template name="get-template-id" />
        <xsl:comment select="' Reportability Response Priority '" />
        <xsl:call-template name="get-id">
          <xsl:with-param name="pNoNullAllowed" select="true()" />
        </xsl:call-template>
        <code code="RR9" codeSystem="2.16.840.1.114222.4.5.232" codeSystemName="PHIN Questions" displayName="Reportability response priority" />
        <xsl:apply-templates select="fhir:valueCodeableConcept">
          <xsl:with-param name="pElementName" select="'value'" />
          <xsl:with-param name="pXSIType" select="'CD'" />
        </xsl:apply-templates>
      </observation>
    </entry>
  </xsl:template>

  <!-- Gender Identity -->
  <xsl:template match="fhir:extension[@url = 'http://hl7.org/fhir/StructureDefinition/patient-genderIdentity']" mode="entry">
    <xsl:param name="generated-narrative">additional</xsl:param>
    <entry>
      <xsl:if test="$generated-narrative = 'generated'">
        <xsl:attribute name="typeCode">DRIV</xsl:attribute>
      </xsl:if>
      <observation classCode="OBS" moodCode="EVN">
        <xsl:comment select="' [NHCS R1D3] Gender Identity Observation '" />
        <templateId root="2.16.840.1.113883.10.20.34.3.45" extension="2019-04-01" />
        <id nullFlavor="NI" />
        <code code="76691-5" displayName="Gender identity" codeSystem="2.16.840.1.113883.6.1" codeSystemName="LOINC" />
        <statusCode code="completed" />
        <effectiveTime value="{//fhir:Composition/fhir:date/@value}" />
        <xsl:apply-templates select="fhir:valueCodeableConcept">
          <xsl:with-param name="pElementName" select="'value'" />
          <xsl:with-param name="pXSIType" select="'CD'" />
        </xsl:apply-templates>
      </observation>
    </entry>
  </xsl:template>

  <!-- Birth Sex -->
  <xsl:template match="fhir:extension[@url = 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-birthsex']" mode="entry">
    <xsl:param name="generated-narrative">additional</xsl:param>
    <entry>
      <xsl:if test="$generated-narrative = 'generated'">
        <xsl:attribute name="typeCode">DRIV</xsl:attribute>
      </xsl:if>
      <observation classCode="OBS" moodCode="EVN">
        <xsl:comment select="' [C-CDA R2.1 Companion Guide] Birth Sex Observation '" />
        <templateId root="2.16.840.1.113883.10.20.22.4.200" extension="2016-06-01" />
        <code code="76689-9" codeSystem="2.16.840.1.113883.6.1" displayName="Sex Assigned At Birth" />
        <statusCode code="completed" />
        <xsl:apply-templates select="parent::*/fhir:birthDate">
          <xsl:with-param name="pElementName" select="'effectiveTime'" />
        </xsl:apply-templates>
        <xsl:choose>
          <xsl:when test="fhir:valueCode/@value = 'F'">
            <value xsi:type="CD" codeSystem="2.16.840.1.113883.5.1" codeSystemName="AdministrativeGender" code="F" displayName="Female" />
          </xsl:when>
          <xsl:when test="fhir:valueCode/@value = 'M'">
            <value xsi:type="CD" codeSystem="2.16.840.1.113883.5.1" codeSystemName="AdministrativeGender" code="M" displayName="Male" />
          </xsl:when>
          <xsl:when test="fhir:valueCode/@value = 'UNK'">
            <value xsi:type="CD" nullFlavor="UNK" />
          </xsl:when>
        </xsl:choose>
      </observation>
    </entry>
  </xsl:template>

  <xsl:key name="outcome-references" match="fhir:Goal[fhir:outcomeReference]" use="fhir:outcomeReference/fhir:reference/@value" />

  <xsl:template match="fhir:Observation[ancestor::fhir:entry/fhir:fullUrl/@value = //fhir:Goal/fhir:outcomeReference/fhir:reference/@value]" mode="entry">
    <xsl:param name="generated-narrative">additional</xsl:param>
    <xsl:comment>Outcome Observation</xsl:comment>
    <entry>
      <xsl:if test="$generated-narrative = 'generated'">
        <xsl:attribute name="typeCode">DRIV</xsl:attribute>
      </xsl:if>
      <xsl:call-template name="make-outcome-observation" />
    </entry>
  </xsl:template>

  <xsl:template name="make-outcome-observation">

    <observation classCode="OBS" moodCode="EVN">
      <!-- [CCDA R2.0] Outcome Observation -->
      <templateId root="2.16.840.1.113883.10.20.22.4.144" />
      <!-- [PCP R1 STU1] Outcome Observation -->
      <templateId root="2.16.840.1.113883.10.20.37.3.16" extension="2017-08-01" />
      <xsl:call-template name="get-id" />

      <xsl:for-each select="fhir:code">
        <xsl:call-template name="CodeableConcept2CD" />
      </xsl:for-each>
      <statusCode code="completed" />
      <effectiveTime>
        <xsl:choose>

          <xsl:when test="fhir:effectiveDateTime/@value">
            <low>
              <xsl:attribute name="value">
                <xsl:call-template name="Date2TS">
                  <xsl:with-param name="date" select="fhir:effectiveDateTime/@value" />
                  <xsl:with-param name="includeTime" select="true()" />
                </xsl:call-template>
              </xsl:attribute>
            </low>
          </xsl:when>
          <xsl:otherwise>
            <xsl:attribute name="nullFlavor">NI</xsl:attribute>
            <low nullFlavor="NI" />
          </xsl:otherwise>
        </xsl:choose>
      </effectiveTime>
    </observation>
  </xsl:template>

  <xsl:template match="fhir:item[fhir:linkId/@value = 'event-type']" mode="infection">
    <observation classCode="OBS" moodCode="EVN" negationInd="false">
      <!-- [C-CDA R1.1] Problem Observation -->
      <templateId root="2.16.840.1.113883.10.20.22.4.4" />
      <!-- [HAI R2N1] Infection-Type Observation -->
      <templateId root="2.16.840.1.113883.10.20.5.6.139" />
      <id root="{$docId}" extension="{$infection-id}" />
      <code code="ASSERTION" codeSystem="2.16.840.1.113883.5.4" />
      <statusCode code="completed" />
      <effectiveTime>
        <low value="20180102" />
      </effectiveTime>
      <xsl:message>Outputting infection-type observation</xsl:message>
      <xsl:for-each select="fhir:answer[fhir:valueCoding]">
        <xsl:call-template name="CodeableConcept2CD">
          <xsl:with-param name="pElementName">value</xsl:with-param>
          <xsl:with-param name="pXSIType">CD</xsl:with-param>
        </xsl:call-template>
      </xsl:for-each>
      <xsl:apply-templates select="//fhir:item[fhir:linkId[@value = 'criteria-used']]" mode="diagnosis" />
      <xsl:apply-templates select="//fhir:item[fhir:linkId[@value = 'infection-condition']]" mode="condition" />
    </observation>
  </xsl:template>

  <!-- The below is specific to PCP usually Vital Signs are in Organizers, not Health Concern Act... 
       changed name and added logic so that only PCP uses this code-->
  <xsl:template name="make-vitalsign-in-health-concern">
    <act classCode="ACT" moodCode="EVN">
      <!-- [C-CDA R2.1] Health Concern Act (V2) -->
      <templateId root="2.16.840.1.113883.10.20.22.4.132" extension="2015-08-01" />
      <!-- [PCP R1 STU1] Health Concern Act (Pharmacist Care Plan) -->
      <templateId root="2.16.840.1.113883.10.20.37.3.8" extension="2017-08-01" />
      <id nullFlavor="NI" />
      <code code="75310-3" codeSystem="2.16.840.1.113883.6.1" displayName="Health Concern" codeSystemName="LOINC" />
      <statusCode code="active" />
      <entryRelationship typeCode="REFR">
        <xsl:apply-templates select="." />
        <!--<xsl:call-template name="make-vitalsign" />-->
      </entryRelationship>
    </act>
  </xsl:template>

  <!-- Pulled the actual vital sign obs out of make-vitalsign-in-health-concern to make it 
       standalone so we can use in other use cases-->
  <!-- A Vital Sign Observation from FHIR translates to an Observation if it doesn't contain hasMember 
      (if it does contain hasMember it's an Organizer) -->
  <xsl:template name="make-vitalsign">
    <observation classCode="OBS" moodCode="EVN">
      <xsl:apply-templates select="." mode="map-resource-to-template" />
      <xsl:call-template name="get-id" />
      <xsl:apply-templates select="fhir:code" />

      <statusCode code="completed" />
      <xsl:choose>
        <xsl:when test="fhir:effectiveDateTime">
          <xsl:apply-templates select="fhir:effectiveDateTime" />
        </xsl:when>
        <xsl:otherwise>
          <effectiveTime nullFlavor="NI" />
        </xsl:otherwise>
      </xsl:choose>
      <xsl:for-each select="fhir:valueQuantity">
        <value xsi:type="PQ" value="{fhir:value/@value}" unit="{fhir:unit/@value}" />
      </xsl:for-each>
      <xsl:for-each select="fhir:interpretation">
        <xsl:call-template name="CodeableConcept2CD">
          <xsl:with-param name="pElementName">interpretationCode</xsl:with-param>
        </xsl:call-template>
      </xsl:for-each>
    </observation>
  </xsl:template>

  <!-- Planned Observation (Observation) fhir:ServiceRequest -->
  <xsl:template match="fhir:ServiceRequest" mode="entry">
    <!-- Check to see if this is a trigger code template -->
    <xsl:variable name="vTriggerEntry">
      <xsl:call-template name="check-for-trigger" />
    </xsl:variable>
    <xsl:variable name="vTriggerExtension" select="$vTriggerEntry/fhir:extension" />
    <entry>
      <observation classCode="OBS" moodCode="RQO">
        <!-- templateId -->
        <xsl:call-template name="get-template-id">
          <xsl:with-param name="pTriggerExtension" select="$vTriggerExtension" />
        </xsl:call-template>
        <xsl:call-template name="get-id" />
        <statusCode code="active" />
        <xsl:call-template name="get-effective-time" />
        <!--<xsl:choose>
          <xsl:when test="fhir:occurrenceDateTime">
            <xsl:apply-templates select="fhir:occurrenceDateTime" />
          </xsl:when>
          <xsl:otherwise>
            <effectiveTime nullFlavor="NI" />
          </xsl:otherwise>
        </xsl:choose>-->
        <xsl:apply-templates select="fhir:code" />
        <xsl:if test="fhir:priority">
          <entryRelationship typeCode="REFR">
            <priority value="{fhir:priority/@value}" />
          </entryRelationship>
        </xsl:if>
      </observation>
    </entry>
  </xsl:template>

  <xsl:template match="//fhir:item[fhir:linkId[@value = 'pathogen-identified']]" mode="pathogen-identified">
    <observation classCode="OBS" moodCode="EVN">
      <templateId root="2.16.840.1.113883.10.20.22.4.2" />
      <templateId root="2.16.840.1.113883.10.20.5.6.145" />
      <id nullFlavor="NA" />
      <code code="41852-5" codeSystem="2.16.840.1.113883.6.1" displayName="Microogranism identified" />
      <statusCode code="completed" />
      <effectiveTime nullFlavor="NA" />
      <xsl:for-each select="fhir:answer[fhir:valueCoding]">
        <xsl:call-template name="CodeableConcept2CD">
          <xsl:with-param name="pElementName">value</xsl:with-param>
          <xsl:with-param name="pXSIType">CD</xsl:with-param>
        </xsl:call-template>
      </xsl:for-each>
    </observation>
  </xsl:template>

  <xsl:template match="//fhir:item[fhir:linkId[@value = 'pathogen-ranking']]" mode="pathogen-ranking">
    <observation classCode="OBS" moodCode="EVN">
      <!-- Problem Observation -->
      <templateId root="2.16.840.1.113883.10.20.22.4.4" />
      <!-- Pathogen Ranking Observation -->
      <templateId root="2.16.840.1.113883.10.20.5.6.147" />
      <id nullFlavor="NA" />
      <code code="ASSERTION" codeSystem="2.16.840.1.113883.5.4" />
      <statusCode code="completed" />
      <xsl:for-each select="fhir:answer[fhir:valueCoding]">
        <xsl:call-template name="CodeableConcept2CD">
          <xsl:with-param name="pElementName">value</xsl:with-param>
          <xsl:with-param name="pXSIType">CD</xsl:with-param>
        </xsl:call-template>
      </xsl:for-each>
    </observation>
  </xsl:template>

  <xsl:template name="no-pathogens-found">
    <!-- Not sure how to show that no pathogens were found -->
  </xsl:template>

  <!-- Problem Observation -->
  <xsl:template name="make-problem-observation">

    <!-- Check to see if this is a trigger code template -->
    <xsl:variable name="vTriggerEntry">
      <xsl:call-template name="check-for-trigger" />
    </xsl:variable>
    <xsl:variable name="vTriggerExtension" select="$vTriggerEntry/fhir:extension" />
    <observation>
      <xsl:attribute name="classCode" select="'OBS'" />
      <xsl:attribute name="moodCode" select="'EVN'" />
      <xsl:if test="$vTriggerExtension">
        <xsl:attribute name="negationInd" select="'false'" />
      </xsl:if>

      <!-- templateId -->
      <xsl:call-template name="get-template-id">
        <xsl:with-param name="pTriggerExtension" select="$vTriggerExtension" />
      </xsl:call-template>
      <!-- id -->
      <xsl:call-template name="get-id" />
      <!-- code -->

      <!-- Should have already wrapped this with an encounter diagnosis, hard code that one or deal with the others -->
      <xsl:choose>
        <xsl:when test="fhir:category[fhir:coding/fhir:code/@value = 'encounter-diagnosis']">
          <code code="29308-4" codeSystem="2.16.840.1.113883.6.1" codeSystemName="LOINC" displayName="Diagnosis">
            <translation code="282291009" codeSystem="2.16.840.1.113883.6.96" codeSystemName="SNOMED CT" displayName="Diagnosis interpretation" />
          </code>
        </xsl:when>
        <xsl:otherwise>
          <xsl:apply-templates select="fhir:category[not(fhir:coding/fhir:code/@value = 'encounter-diagnosis')]" />
        </xsl:otherwise>
      </xsl:choose>
      <xsl:if test="fhir:note">
        <text>
          <xsl:value-of select="fhir:note/fhir:text/@value" />
        </text>
      </xsl:if>
      <statusCode code="completed" />
      <effectiveTime>
        <xsl:choose>
          <xsl:when test="fhir:onsetDateTime/@value">
            <low>
              <xsl:attribute name="value">
                <xsl:call-template name="Date2TS">
                  <xsl:with-param name="date" select="fhir:onsetDateTime/@value" />
                  <xsl:with-param name="includeTime" select="true()" />
                </xsl:call-template>
              </xsl:attribute>
            </low>
          </xsl:when>
          <xsl:otherwise>
            <xsl:attribute name="nullFlavor">NI</xsl:attribute>
            <low nullFlavor="NI" />
          </xsl:otherwise>
        </xsl:choose>
        <xsl:if test="fhir:abatementDateTime">
          <high>
            <xsl:attribute name="value">
              <xsl:call-template name="Date2TS">
                <xsl:with-param name="date" select="fhir:abatementDateTime/@value" />
                <xsl:with-param name="includeTime" select="true()" />
              </xsl:call-template>
            </xsl:attribute>
          </high>
        </xsl:if>
      </effectiveTime>
      <xsl:apply-templates select="fhir:code">
        <xsl:with-param name="pElementName" select="'value'" />
        <xsl:with-param name="pXSIType" select="'CD'" />
        <xsl:with-param name="pTriggerExtension" select="$vTriggerExtension" />
      </xsl:apply-templates>
    </observation>
  </xsl:template>

  <!-- RR processing status reason -->
  <xsl:template match="fhir:Observation[fhir:meta/fhir:profile/@value = 'http://hl7.org/fhir/us/ecr/StructureDefinition/rr-eicr-processing-status-reason-observation']" mode="communication">
    <entryRelationship typeCode="RSON">
      <observation classCode="OBS" moodCode="EVN">
        <xsl:call-template name="get-template-id" />
        <xsl:call-template name="get-id" />
        <xsl:apply-templates select="fhir:code" />
        <xsl:apply-templates select="fhir:valueCodeableConcept">
          <xsl:with-param name="pElementName" select="'value'" />
          <xsl:with-param name="pXSIType" select="'CD'" />
        </xsl:apply-templates>
        <!-- eICR Processing Status Reason Details -->
        <xsl:for-each select="fhir:component">
          <entryRelationship typeCode="RSON">
            <observation classCode="OBS" moodCode="EVN">
              <xsl:comment select="' [RR R1S1] eICR Processing Status Reason Details '" />
              <templateId root="2.16.840.1.113883.10.20.15.2.3.32" extension="2017-04-01" />
              <xsl:apply-templates select="fhir:code" />
              <value xsi:type="ST">
                <xsl:value-of select="fhir:valueString/@value" />
              </value>
            </observation>
          </entryRelationship>
        </xsl:for-each>
      </observation>
    </entryRelationship>
  </xsl:template>

  <xsl:template match="fhir:extension[@url = 'eICRValidationOutput']" mode="communication">
    <entryRelationship typeCode="SPRT">
      <observation classCode="OBS" moodCode="EVN">
        <xsl:call-template name="get-template-id" />
        <id nullFlavor="NI" />
        <code code="RR10" displayName="eICR Validation Output" codeSystem="2.16.840.1.114222.4.5.232" codeSystemName="PHIN Questions" />
        <value xsi:type="ED" mediaType="text/xhtml">
          <xsl:value-of select="fhir:valueString/@value" disable-output-escaping="yes" />
        </value>
      </observation>
    </entryRelationship>

  </xsl:template>

  <xsl:template name="make-relevant-condition-observation">
    <component>
      <!-- Relevant Reportable Condition Observation [1..*]: one for each condition-->
      <!-- So there could be multiple PlanDefinitions with the same condition - we need the condition only once...  
           We are inside a for-each-group (grouped by condition) so we can just grab the condition here -->
      <observation classCode="OBS" moodCode="EVN">
        <xsl:call-template name="get-template-id" />
        <code code="64572001" codeSystem="2.16.840.1.113883.6.96" codeSystemName="SNOMED" displayName="Condition">
          <translation code="75323-6" codeSystem="2.16.840.1.113883.6.1" codeSystemName="LOINC" displayName="Condition" />
        </code>
        <xsl:apply-templates select="fhir:goal/fhir:addresses">
          <xsl:with-param name="pXSIType" select="'CD'" />
          <xsl:with-param name="pElementName" select="'value'" />
        </xsl:apply-templates>
        <!-- Now iterate through each of the PlanDefinitions in the current group (based on Condition)
             This will take us to the Organizer code for PlanDefinition-->
        <xsl:for-each select="current-group()">
          <xsl:apply-templates select="." mode="communication" />
        </xsl:for-each>
      </observation>
    </component>
  </xsl:template>

  <xsl:template match="*" mode="debug">
    <xsl:comment>
      <xsl:value-of select="local-name(.)" />
    </xsl:comment>
  </xsl:template>

</xsl:stylesheet>
