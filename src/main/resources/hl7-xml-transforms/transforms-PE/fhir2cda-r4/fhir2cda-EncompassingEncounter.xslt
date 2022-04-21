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
  xmlns:xhtml="http://www.w3.org/1999/xhtml" version="2.0" exclude-result-prefixes="lcg xsl cda fhir xhtml">

  <xsl:import href="fhir2cda-utility.xslt" />
  <xsl:import href="fhir2cda-CD.xslt" />
  <xsl:import href="fhir2cda-TS.xslt" />

  <!-- fhir:encounter -> get referenced resource entry url and process -->
  <xsl:template match="fhir:encounter">
    <xsl:for-each select="fhir:reference">
      <xsl:variable name="referenceURI">
        <xsl:call-template name="resolve-to-full-url">
          <xsl:with-param name="referenceURI" select="@value" />
        </xsl:call-template>
      </xsl:variable>
      <xsl:for-each select="//fhir:entry[fhir:fullUrl/@value = $referenceURI]">
        <xsl:apply-templates select="fhir:resource/fhir:*" mode="encompassing-encounter" />
      </xsl:for-each>
    </xsl:for-each>
  </xsl:template>

  <xsl:template match="fhir:entry/fhir:resource/fhir:Encounter" mode="encompassing-encounter">
    <xsl:call-template name="make-encompassing-encounter" />
  </xsl:template>

  <xsl:template name="make-encompassing-encounter">
    <!-- Put the PractitionerRole into a variable (can be multiple in base Encounter resource, but only 1 (type=ATND) allowed in eICR) -->
    <xsl:variable name="referenceURI">
      <xsl:call-template name="resolve-to-full-url">
        <xsl:with-param name="referenceURI" select="fhir:participant/fhir:individual/fhir:reference/@value" />
      </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="vPractitionerRole" select="//fhir:entry[fhir:fullUrl/@value = $referenceURI]/fhir:resource/fhir:PractitionerRole" />

    <!-- Put the Practitioner into a variable (max 1 in base PractitionerRole resource) -->
    <xsl:variable name="referenceURI">
      <xsl:call-template name="resolve-to-full-url">
        <xsl:with-param name="referenceURI" select="$vPractitionerRole/fhir:practitioner/fhir:reference/@value" />
      </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="vPractitioner" select="//fhir:entry[fhir:fullUrl/@value = $referenceURI]/fhir:resource/fhir:Practitioner" />

    <!-- Put the organization into a variable (max 1 in base PractitionerRole resource) -->
    <xsl:variable name="referenceURI">
      <xsl:call-template name="resolve-to-full-url">
        <xsl:with-param name="referenceURI" select="$vPractitionerRole/fhir:organization/fhir:reference/@value" />
      </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="vOrganization" select="//fhir:entry[fhir:fullUrl/@value = $referenceURI]/fhir:resource/fhir:Organization" />

    <!-- Put the Location into a variable (can be multiple in base Encounter resource) -->
    <xsl:variable name="referenceURI">
      <xsl:call-template name="resolve-to-full-url">
        <xsl:with-param name="referenceURI" select="fhir:location/fhir:location/fhir:reference/@value" />
      </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="vLocation" select="//fhir:entry[fhir:fullUrl/@value = $referenceURI]/fhir:resource/fhir:Location" />

    <!-- Put the Location.managingOrganization into a variable -->
    <xsl:variable name="referenceURI">
      <xsl:call-template name="resolve-to-full-url">
        <xsl:with-param name="referenceURI" select="$vLocation/fhir:managingOrganization/fhir:reference/@value" />
      </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="vLocationManagingOrganization" select="//fhir:entry[fhir:fullUrl/@value = $referenceURI]/fhir:resource/fhir:Organization" />



    <!-- Put the ServiceProvider into a variable (1 max in base Encounter resource) -->
    <xsl:variable name="referenceURI">
      <xsl:call-template name="resolve-to-full-url">
        <xsl:with-param name="referenceURI" select="fhir:serviceProvider/fhir:reference/@value" />
      </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="vServiceProvider" select="//fhir:entry[fhir:fullUrl/@value = $referenceURI]/fhir:resource/fhir:Organization" />

    <componentOf>
      <encompassingEncounter>
        <xsl:call-template name="get-id" />

        <!-- For some reason eICR is different than PCP for encompassingEncounter.code -->
        <xsl:choose>
          <xsl:when test="$gvCurrentIg = 'eICR'">
            <code>
              <xsl:apply-templates select="fhir:class" />
              <xsl:for-each select="fhir:type">
                <xsl:apply-templates select=".">
                  <xsl:with-param name="pElementName" select="'translation'" />
                </xsl:apply-templates>
              </xsl:for-each>
            </code>
          </xsl:when>
          <xsl:otherwise>
            <xsl:for-each select="fhir:type">
              <xsl:call-template name="CodeableConcept2CD" />
            </xsl:for-each>
          </xsl:otherwise>
        </xsl:choose>

        <xsl:apply-templates select="fhir:period" />

        <!-- Refactor -->
        <responsibleParty>
          <assignedEntity>
            <!-- eICR is different -->
            <xsl:choose>
              <xsl:when test="$gvCurrentIg = 'eICR' or $gvCurrentIg = 'RR'">
                <xsl:choose>
                  <xsl:when test="$vPractitionerRole/fhir:identifier">
                    <xsl:variable name="vPotentialDupes">
                      <xsl:apply-templates select="$vPractitionerRole/fhir:identifier" />
                    </xsl:variable>
                    <xsl:for-each-group select="$vPotentialDupes/cda:id" group-by="concat(@root, @extension)">
                      <xsl:copy-of select="current-group()[1]" />
                    </xsl:for-each-group>
                  </xsl:when>
                  <xsl:otherwise>
                    <id nullFlavor="NI" root="2.16.840.1.113883.4.6" />
                  </xsl:otherwise>
                </xsl:choose>
                <!--<xsl:call-template name="get-id">
                  <xsl:with-param name="pElement" select="$vPractitionerRole/fhir:identifier" />
                </xsl:call-template>-->
                <xsl:call-template name="get-addr">
                  <xsl:with-param name="pElement" select="$vPractitioner/fhir:address" />
                </xsl:call-template>
                <xsl:call-template name="get-telecom">
                  <xsl:with-param name="pElement" select="$vPractitioner/fhir:telecom" />
                </xsl:call-template>

                <assignedPerson>
                  <xsl:call-template name="get-person-name">
                    <xsl:with-param name="pElement" select="$vPractitioner/fhir:name" />
                  </xsl:call-template>
                </assignedPerson>
                <representedOrganization>
                  <xsl:call-template name="get-id">
                    <xsl:with-param name="pElement" select="$vOrganization/fhir:identifier" />
                  </xsl:call-template>
                  <xsl:call-template name="get-org-name">
                    <xsl:with-param name="pElement" select="$vOrganization/fhir:name" />
                  </xsl:call-template>
                  <xsl:call-template name="get-telecom">
                    <xsl:with-param name="pElement" select="$vOrganization/fhir:telecom" />
                  </xsl:call-template>
                  <xsl:call-template name="get-addr">
                    <xsl:with-param name="pElement" select="$vOrganization/fhir:address" />
                  </xsl:call-template>
                </representedOrganization>
              </xsl:when>
              <xsl:otherwise>
                <xsl:for-each select="fhir:participant/fhir:individual/fhir:reference">
                  <xsl:variable name="referenceURI" select="@value" />
                  <xsl:for-each select="//fhir:entry[fhir:fullUrl/@value = $referenceURI]">
                    <xsl:apply-templates select="fhir:resource/fhir:*" mode="encompassing-encounter" />
                  </xsl:for-each>
                </xsl:for-each>
              </xsl:otherwise>
            </xsl:choose>
          </assignedEntity>
        </responsibleParty>
        <location>
          <healthCareFacility>
            <!-- Refactor -->
            <xsl:choose>
              <xsl:when test="$vLocation/fhir:identifier">
                <xsl:choose>
                  <xsl:when test="$vLocation/fhir:identifier">
                    <xsl:variable name="vPotentialDupes">
                      <xsl:apply-templates select="$vLocation/fhir:identifier" />
                    </xsl:variable>
                    <xsl:for-each-group select="$vPotentialDupes/cda:id" group-by="concat(@root, @extension)">
                      <xsl:copy-of select="current-group()[1]" />
                    </xsl:for-each-group>
                  </xsl:when>
                  <xsl:otherwise>
                    <id nullFlavor="NI" root="2.16.840.1.113883.4.6" />
                  </xsl:otherwise>
                </xsl:choose>
                
                <!--<xsl:call-template name="get-id">
                  <xsl:with-param name="pElement" select="$vLocation/fhir:identifier" />
                </xsl:call-template>-->
              </xsl:when>
              <xsl:otherwise>
                <xsl:choose>
                  <xsl:when test="$vLocationManagingOrganization/fhir:identifier">
                    <xsl:variable name="vPotentialDupes">
                      <xsl:apply-templates select="$vLocationManagingOrganization/fhir:identifier" />
                    </xsl:variable>
                    <xsl:for-each-group select="$vPotentialDupes/cda:id" group-by="concat(@root, @extension)">
                      <xsl:copy-of select="current-group()[1]" />
                    </xsl:for-each-group>
                  </xsl:when>
                  <xsl:otherwise>
                    <id nullFlavor="NI" root="2.16.840.1.113883.4.6" />
                  </xsl:otherwise>
                </xsl:choose>
                <!--<xsl:call-template name="get-id">
                  <xsl:with-param name="pElement" select="$vLocationManagingOrganization/fhir:identifier" />
                </xsl:call-template>-->
              </xsl:otherwise>
            </xsl:choose>
            <xsl:apply-templates select="$vLocation/fhir:type" />
            <location>
              <xsl:call-template name="get-org-name">
                <xsl:with-param name="pElement" select="$vLocation/fhir:name" />
              </xsl:call-template>
              <xsl:call-template name="get-addr">
                <xsl:with-param name="pElement" select="$vLocation/fhir:address" />
              </xsl:call-template>
            </location>
            <serviceProviderOrganization>
              <xsl:call-template name="get-org-name">
                <xsl:with-param name="pElement" select="$vServiceProvider/fhir:name" />
              </xsl:call-template>
              <xsl:call-template name="get-telecom">
                <xsl:with-param name="pElement" select="$vServiceProvider/fhir:telecom" />
              </xsl:call-template>
              <xsl:call-template name="get-addr">
                <xsl:with-param name="pElement" select="$vServiceProvider/fhir:address" />
                <xsl:with-param name="pNoNullAllowed" select="true()" />
              </xsl:call-template>
            </serviceProviderOrganization>
          </healthCareFacility>
        </location>
      </encompassingEncounter>
    </componentOf>
  </xsl:template>

  <xsl:template name="make-encompassing-encounter-hai">
    <componentOf>
      <encompassingEncounter>
        <xsl:apply-templates select="//fhir:item[fhir:linkId/@value = 'event-number']/fhir:answer/fhir:valueUri" mode="make-ii" />
        <effectiveTime>
          <xsl:apply-templates select="//fhir:item[fhir:linkId/@value = 'date-admitted-to-facility']/fhir:answer/fhir:valueDate">
            <xsl:with-param name="pElementName">low</xsl:with-param>
          </xsl:apply-templates>
          <xsl:apply-templates select="//fhir:item[fhir:linkId/@value = 'discharge-date']/fhir:answer/fhir:valueDate">
            <xsl:with-param name="pElementName">high</xsl:with-param>
          </xsl:apply-templates>
        </effectiveTime>

        <location>
          <healthCareFacility>
            <xsl:apply-templates select="fhir:item[fhir:linkId/@value = 'facility']/fhir:answer/fhir:valueUri" />
            <xsl:apply-templates select="fhir:item[fhir:linkId/@value = 'facility-location']/fhir:answer" />

          </healthCareFacility>
        </location>
      </encompassingEncounter>
    </componentOf>
  </xsl:template>

  <xsl:template match="fhir:entry/fhir:resource/fhir:Practitioner" mode="encompassing-encounter">
    <xsl:call-template name="get-encounter-practitioner" />
  </xsl:template>

  <xsl:template name="get-encounter-practitioner">
    <xsl:choose>
      <xsl:when test="fhir:identifier">
        <xsl:apply-templates select="fhir:identifier" />
      </xsl:when>
      <xsl:otherwise>
        <id nullFlavor="NI" />
      </xsl:otherwise>
    </xsl:choose>
    <xsl:call-template name="get-addr">
      <xsl:with-param name="pElement" select="fhir:address" />
    </xsl:call-template>
    <xsl:call-template name="get-telecom">
      <xsl:with-param name="pElement" select="fhir:telecom" />
    </xsl:call-template>
    <assignedPerson>
      <xsl:apply-templates select="fhir:name" />
    </assignedPerson>
  </xsl:template>

</xsl:stylesheet>
