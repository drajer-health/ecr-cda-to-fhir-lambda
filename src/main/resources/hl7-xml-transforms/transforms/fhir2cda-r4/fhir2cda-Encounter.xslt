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

  <!-- eICR Encounter Activities (Encounter) -->
  <!-- The Encounters Section and in turn Encounter Activities for eICR is created from 
       Composition.encounter - there isn't a section in the Composition, so we need to 
       manually create the Section and encounter -->
  <xsl:template match="fhir:Encounter" mode="encounter">
    <entry typeCode="DRIV">
      <encounter classCode="ENC" moodCode="EVN">
        <xsl:comment select="' [C-CDA R1.1] Encounter Activities '" />
        <templateId root="2.16.840.1.113883.10.20.22.4.49" />
        <xsl:comment select="' [C-CDA R2.1] Encounter Activities (V3) '" />
        <templateId root="2.16.840.1.113883.10.20.22.4.49" extension="2015-08-01" />
        <!-- We don't have an id to use here so generate one -->
        <id root="{lower-case(uuid:get-uuid())}" />
        <xsl:apply-templates select="fhir:type" />
        <xsl:apply-templates select="fhir:period" />
        <xsl:apply-templates select="fhir:diagnosis" />
      </encounter>
    </entry>
  </xsl:template>
  
  <!-- fhir:diagnosis -> get referenced resource entry url and process -->
  <xsl:template match="fhir:diagnosis">
      <xsl:for-each select="fhir:condition/fhir:reference">
        <xsl:variable name="referenceURI">
          <xsl:call-template name="resolve-to-full-url">
            <xsl:with-param name="referenceURI" select="@value" />
          </xsl:call-template>
        </xsl:variable>
        
        <xsl:for-each select="//fhir:entry[fhir:fullUrl/@value = $referenceURI]">
          <xsl:apply-templates select="fhir:resource/fhir:*" mode="entry-relationship">
            <xsl:with-param name="pTypeCode" select="'COMP'" />
          </xsl:apply-templates>
        </xsl:for-each>
      </xsl:for-each>
  </xsl:template>

</xsl:stylesheet>
