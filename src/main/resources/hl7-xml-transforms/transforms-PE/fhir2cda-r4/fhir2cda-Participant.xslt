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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns="urn:hl7-org:v3" xmlns:lcg="http://www.lantanagroup.com" xmlns:cda="urn:hl7-org:v3" xmlns:fhir="http://hl7.org/fhir" version="2.0"
  exclude-result-prefixes="lcg xsl cda fhir">

  <xsl:import href="fhir2cda-utility.xslt" />
  <xsl:import href="fhir2cda-TS.xslt" />


  <xsl:template match="fhir:Organization" mode="communication">

    <participant typeCode="LOC">
      <xsl:call-template name="get-template-id" />

      <participantRole>
        <xsl:apply-templates select="fhir:identifier" />
        <xsl:apply-templates select="fhir:type">
          <xsl:with-param name="pElementName" select="'code'" />
        </xsl:apply-templates>
        <xsl:call-template name="get-addr" />
        <xsl:call-template name="get-telecom" />

        <playingEntity>
          <xsl:call-template name="get-org-name" />
        </playingEntity>
      </participantRole>
    </participant>

  </xsl:template>
</xsl:stylesheet>
