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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns="urn:hl7-org:v3" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:lcg="http://www.lantanagroup.com" xmlns:cda="urn:hl7-org:v3"
  xmlns:fhir="http://hl7.org/fhir" xmlns:uuid="http://www.uuid.org" xmlns:xhtml="http://www.w3.org/1999/xhtml" version="2.0" exclude-result-prefixes="lcg xsl cda fhir xhtml uuid">

  <xsl:import href="fhir2cda-utility.xslt" />

  <xsl:output method="xml" indent="yes" encoding="UTF-8" />

  <!-- fhir:section -> cda:section (Generic) -->
  <xsl:template match="fhir:section">
    <xsl:param name="title" />
    <section>
      <xsl:variable name="generated-narrative" select="fhir:text/fhir:status/@value" />
      <!--xsl:apply-templates select="fhir:extension[1]" mode="templateId"/-->
      <!--<xsl:call-template name="section-templates" />-->

      <!-- templateId -->
      <xsl:call-template name="get-template-id" />

      <xsl:apply-templates select="fhir:code" />
      <title>
        <xsl:value-of select="$title" />
      </title>
      <text>
        <xsl:if test="normalize-space(fhir:text/xhtml:div/xhtml:div[@class = 'custom']) != 'No information.'">
          <xsl:apply-templates select="fhir:text" mode="narrative" />
        </xsl:if>
      </text>
      <!-- fhir:entry -> get referenced resource entry url and process -->
      <xsl:for-each select="fhir:entry">
        <xsl:for-each select="fhir:reference">
          <xsl:variable name="referenceURI">
            <xsl:call-template name="resolve-to-full-url">
              <xsl:with-param name="referenceURI" select="@value" />
            </xsl:call-template>
          </xsl:variable>
          <xsl:for-each select="//fhir:entry[fhir:fullUrl/@value = $referenceURI]">
            <!-- Process for all entry elements other than Pregnancy Outcome - it's an entryRelationship of Pregnancy Observation in CDA -->
            <xsl:if test="not(fhir:resource/fhir:Observation/fhir:meta/fhir:profile/@value = 'http://hl7.org/fhir/us/ecr/StructureDefinition/pregnancy-outcome-observation')">
              <xsl:apply-templates select="fhir:resource/fhir:*" mode="entry">
                <xsl:with-param name="generated-narrative" />
              </xsl:apply-templates>
            </xsl:if>
          </xsl:for-each>
        </xsl:for-each>
      </xsl:for-each>

      <!-- If this is the Social History Section, we need to process Birth Sex and Gender Identity (extensions on Composition) as Observations -->
      <xsl:if test="fhir:code/fhir:coding[fhir:system/@value = 'http://loinc.org']/fhir:code/@value = '29762-2'">
        <xsl:apply-templates select="//fhir:extension[@url = 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-birthsex']" mode="entry" />
        <xsl:apply-templates select="//fhir:extension[@url = 'http://hl7.org/fhir/StructureDefinition/patient-genderIdentity']" mode="entry" />
      </xsl:if>
    </section>
  </xsl:template>

  <!-- fhir:Composition/fhir:encounter -> eICR Encounters Section (Section) -->
  <!-- The Encounters Section for eICR is created from Composition.encounter - there isn't a 
        section in the Composition, so we need to manually create the Section -->
  <xsl:template name="create-eicr-encounters-section">
    <section>
      <xsl:comment select="' [C-CDA R1.1] Encounters Section (entries optional) '" />
      <templateId root="2.16.840.1.113883.10.20.22.2.22" />
      <xsl:comment select="' [C-CDA R2.1] Encounters Section (entries optional) (V3) '" />
      <templateId root="2.16.840.1.113883.10.20.22.2.22" extension="2015-08-01" />
      <xsl:comment select="' [C-CDA R1.1] Encounters Section (entries required) '" />
      <templateId root="2.16.840.1.113883.10.20.22.2.22.1" />
      <xsl:comment select="' [C-CDA R2.1] Encounters Section (entries required) (V3) '" />
      <templateId root="2.16.840.1.113883.10.20.22.2.22.1" extension="2015-08-01" />
      <code code="46240-8" codeSystem="2.16.840.1.113883.6.1" codeSystemName="LOINC" displayName="History of encounters" />
      <title>Encounters</title>
      <text>
        <xsl:if test="normalize-space(fhir:text/xhtml:div/xhtml:div[@class = 'custom']) != 'No information.'">
          <xsl:apply-templates select="fhir:text" mode="narrative" />
        </xsl:if>
      </text>
      <xsl:apply-templates select="." mode="encounter" />
    </section>
  </xsl:template>

  <!-- Create the Reportability Response Subject Section - this is basically just some text that is in fhir:topic -->
  <xsl:template match="fhir:topic">
    <section>
      <xsl:call-template name="get-template-id">
        <xsl:with-param name="pElementType" select="'section'" />
      </xsl:call-template>
      <code code="88084-9" codeSystem="2.16.840.1.113883.6.1" codeSystemName="LOINC" displayName="Reportable condition response information and summary Document" />
      <text>
        <br />
        <br />
        <paragraph>
          <content styleCode="Bold">Subject:</content>
        </paragraph>
        <paragraph>
          <xsl:value-of select="fhir:text/@value" />
        </paragraph>
      </text>
      <!-- Create the Reportability Response Subject act -->
      <xsl:apply-templates select="." mode="entry" />
    </section>
  </xsl:template>

  <!-- [RR R1S1] Electronic Initial Case Report Section -->
  <xsl:template match="fhir:payload[@id = 'eicr-information']" mode="communication">
    <component>
      <section>
        <!-- templateId -->
        <xsl:call-template name="get-template-id" />

        <code code="88082-3" codeSystem="2.16.840.1.113883.6.1" codeSystemName="LOINC" displayName="Initial case report processing information Document" />
        <text>
          <xsl:if test="normalize-space(fhir:text/xhtml:div/xhtml:div[@class = 'custom']) != 'No information.'">
            <xsl:apply-templates select="fhir:text" mode="narrative" />
          </xsl:if>
        </text>
        <xsl:apply-templates select="fhir:contentReference" mode="communication" />
        <xsl:apply-templates select="fhir:extension[@url = 'http://hl7.org/fhir/us/ecr/StructureDefinition/rr-eicr-processing-status-extension']" mode="communication" />
        <xsl:apply-templates select="fhir:extension[@url = 'http://hl7.org/fhir/us/ecr/StructureDefinition/eicr-initiation-type-extension']" mode="communication" />
      </section>
    </component>
  </xsl:template>

  <!-- Reportability Response Summary Section -->
  <xsl:template name="make-reportability-response-summary-section">
    <component>
      <section>
        <xsl:comment select="' [RR R1S1] Reportability Response Summary Section '" />
        <templateId root="2.16.840.1.113883.10.20.15.2.2.2" extension="2017-04-01" />
        <code code="55112-7" codeSystem="2.16.840.1.113883.6.1" codeSystemName="LOINC" displayName="Document Summary" />
        <text>
          <xsl:if test="normalize-space(fhir:text/xhtml:div/xhtml:div[@class = 'custom']) != 'No information.'">
            <xsl:apply-templates select="fhir:text" mode="narrative" />
          </xsl:if>
        </text>

        <xsl:apply-templates select="//fhir:payload[@id = 'reportability-response-summary']" mode="communication" />

        <xsl:apply-templates select="fhir:extension[@url = 'http://hl7.org/fhir/us/ecr/StructureDefinition/rr-priority-extension']"/>
        
        <!-- Create the Reportability Response Coded Information Organizer [1..1] -->
        <xsl:call-template name="make-reportability-response-coded-information-organizer"/>

      </section>
    </component>
  </xsl:template>
  
  <!-- fhir:item[not(fhir:answer)] -> (HAI) Generic Section (Section) -->
  <xsl:template match="fhir:item[not(fhir:answer)]">
    <xsl:variable name="vLinkId" select="fhir:linkId/@value"/>
    <section>
      <!-- templateId -->
      <xsl:call-template name="get-template-id"/>
      <code>
        <xsl:apply-templates select="$gvHaiQuestionnaire/fhir:Questionnaire/fhir:item[fhir:linkId/@value = $vLinkId]/fhir:code" />
      </code>
      <!-- title -->
      <xsl:apply-templates select="." mode="map-to-title" />
      
      <text>**TODO** Let's generate the text using the HAI transform - otherwise there is no way to separate the text into sections</text>
      <xsl:if test="$vLinkId='event-details' and //fhir:questionnaire/@value = 'http://hl7.org/fhir/us/hai/Questionnaire/hai-questionnaire-los-event'">
        <xsl:apply-templates select="//fhir:item[fhir:linkId/@value='event-type'][fhir:answer]"/>
      </xsl:if>
      
      <xsl:apply-templates select="fhir:item[fhir:answer]"/>
      
      <xsl:if test="$vLinkId='event-details' and //fhir:questionnaire/@value = 'http://hl7.org/fhir/us/hai/Questionnaire/hai-questionnaire-los-event'">
        <xsl:apply-templates select="//fhir:item[fhir:linkId/@value='inborn-outborn-observation'][fhir:answer]"/>
      </xsl:if>
      <!--<xsl:for-each select="//fhir:item[fhir:linkId[@value = 'risk-factor-central-line']]">
        <entry>
          <xsl:apply-templates select="." mode="risk-observation" />
        </entry>
      </xsl:for-each>
      <xsl:for-each select="//fhir:item[fhir:linkId[@value = 'risk-factor-birth-weight']]">
        <entry>
          <xsl:apply-templates select="." mode="measurement-observation" />
        </entry>
      </xsl:for-each>
      <xsl:for-each select="//fhir:item[fhir:linkId[@value = 'risk-factor-gestational-age']]">
        <entry>
          <xsl:apply-templates select="." mode="gestational-age" />
        </entry>
      </xsl:for-each>-->
    </section>
  </xsl:template>
  
  <!-- (HAI) Infection Details Section (Section) -->
  <xsl:template name="infection-details-section">
    <section>
      <templateId root="2.16.840.1.113883.10.20.5.4.26" />
      <!-- [HAI R3D3] Infection Details in Late Onset Sepsis Report -->
      <templateId root="2.16.840.1.113883.10.20.5.5.64" extension="2018-04-01" />
      <code codeSystem="2.16.840.1.113883.6.1" codeSystemName="LOINC" code="51899-3" displayName="Details" />
      <title>Details Section</title>
      <!-- **TODO** Let's generate the text using the HAI transform - otherwise there is no way to separate the text into sections -->
      <text>
        <xsl:if test="normalize-space(fhir:text/xhtml:div/xhtml:div[@class = 'custom']) != 'No information.'">
          <xsl:apply-templates select="fhir:text" mode="narrative" />
        </xsl:if>
      </text>
      <xsl:for-each select="//fhir:item[fhir:linkId/@value = 'event-type']">
        <entry typeCode="DRIV">
          <!-- somewhere/somehow in CodeableConcept2CD, entryRelationship/organizer/component/observation/value@codeSystem is pulling url, not OID as expected. Entry...value@codeSystem is ok though -->
          <xsl:apply-templates select="." mode="infection" />
        </entry>
      </xsl:for-each>
      <xsl:for-each select="//fhir:item[fhir:linkId[@value = 'inborn-outborn-observation']]">
        <entry typeCode="DRIV">
          <xsl:apply-templates select="." mode="inborn" />
        </entry>
      </xsl:for-each>
      <xsl:for-each select="//fhir:item[fhir:linkId[@value = 'died']]">
        <entry typeCode="DRIV">
          <xsl:apply-templates select="." mode="death" />
        </entry>
      </xsl:for-each>
    </section>
  </xsl:template>
  
  <!-- (HAI) Risk Factors Section (Section) -->
  <xsl:template name="risk-factors-section">
    <section>
      <templateId root="2.16.840.1.113883.10.20.5.4.26" />
      <!-- [HAI R3D3] Risk Factors Section (LOS/Men) -->
      <templateId root="2.16.840.1.113883.10.20.5.5.65" extension="2018-04-01" />
      <code codeSystem="2.16.840.1.113883.6.1" codeSystemName="LOINC" code="51898-5" displayName="Risk Factors" />
      <title>Risk Factors</title>
      <!-- **TODO** Let's generate the text using the HAI transform - otherwise there is no way to separate the text into sections -->
      <text>
        <xsl:if test="normalize-space(fhir:text/xhtml:div/xhtml:div[@class = 'custom']) != 'No information.'">
          <xsl:apply-templates select="fhir:text" mode="narrative" />
        </xsl:if>
      </text>
      <xsl:for-each select="//fhir:item[fhir:linkId[@value = 'risk-factor-central-line']]">
        <entry>
          <xsl:apply-templates select="." mode="risk-observation" />
        </entry>
      </xsl:for-each>
      <xsl:for-each select="//fhir:item[fhir:linkId[@value = 'risk-factor-birth-weight']]">
        <entry>
          <xsl:apply-templates select="." mode="measurement-observation" />
        </entry>
      </xsl:for-each>
      <xsl:for-each select="//fhir:item[fhir:linkId[@value = 'risk-factor-gestational-age']]">
        <entry>
          <xsl:apply-templates select="." mode="gestational-age" />
        </entry>
      </xsl:for-each>
    </section>
  </xsl:template>
  
  <!-- (HAI) Findings Section in an Infection-Type Report (Section) -->
  <xsl:template name="findings-section">
    <section>
      <templateId root="2.16.840.1.113883.10.20.5.5.45" />
      <code code="18769-0" codeSystem="2.16.840.1.113883.6.1" displayName="Findings Section" />
      <title>Findings</title>
      <!-- **TODO** Let's generate the text using the HAI transform - otherwise there is no way to separate the text into sections -->
      <text>
        <xsl:if test="normalize-space(fhir:text/xhtml:div/xhtml:div[@class = 'custom']) != 'No information.'">
          <xsl:apply-templates select="fhir:text" mode="narrative" />
        </xsl:if>
      </text>
      <xsl:choose>
        <!-- Check to see if a finding's group exists. If it doesn't, create an empty observation entry -->
        <xsl:when test="//fhir:item[fhir:linkId[@value = 'findings-group']]">
          <entry>
            <xsl:apply-templates select="//fhir:item[fhir:linkId[@value = 'findings-group']]" mode="findings-organizer" />
          </entry>
        </xsl:when>
        <xsl:otherwise>
          <entry>
            <xsl:call-template name="no-pathogens-found" />
          </entry>
        </xsl:otherwise>
      </xsl:choose>
      
    </section>
  </xsl:template>
  
</xsl:stylesheet>
