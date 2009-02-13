<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:dp="http://www.datapower.com/extensions"
                xmlns:dpconfig="http://www.datapower.com/param/config"
                extension-element-prefixes="dp"
                exclude-result-prefixes="dp dpconfig">
   <xsl:output method="xml" version="1.0" encoding="UTF-8" indent="no"/>

   <!-- global variables -->
   <xsl:variable name="envelope" select="/*"/>
   <xsl:variable name="apHttpConverterUrl" select="'http://hoffa.mirius.fgm.com:28080/dpobserver/DataPowerObserverServlet'"/>

   <!--
   main driver template - calls either dispatchRequest or dispatchResponse
   -->
   <xsl:template match="/">
      <!-- processing server response -->
      <xsl:call-template name="handleResponse"/>
      <!-- do not modify the original response -->
      <xsl:apply-templates select="@*|node()"/>
   </xsl:template>
      
   <!--
   SOAP response handler - sends a copy of the response to AP nano Observer
   -->
   <xsl:template name="handleResponse">
      <dp:aaa-log priority="debug">
         <xsl:value-of select="'*** Enter handleResponse'"/>
      </dp:aaa-log>

      <xsl:variable name="requestMethod" select="dp:http-request-method()"/>
      <xsl:variable name="soapAction" select="dp:http-request-header('SOAPAction')"/>

      <dp:aaa-log priority="debug">
         <xsl:value-of select="concat('*** Request Method: ', $requestMethod)"/>
      </dp:aaa-log>
      
      <dp:aaa-log priority="debug">
         <xsl:value-of select="concat('*** SOAP Action: ', $soapAction)"/>
      </dp:aaa-log>

      <xsl:variable name="httpHeaders">
         <header name="ap_soapAction"><xsl:value-of select="$soapAction"/></header>
         <header name="ap_method"><xsl:value-of select="$requestMethod"/></header>
         <!-- retrieve the interaction ID of the originating request -->
         <header name="ap_interactionId"><xsl:value-of select="dp:variable('var://context/amberpoint/interactionId')"/></header>
      </xsl:variable>
      
      <dp:aaa-log priority="debug">
         <xsl:value-of select="concat('*** Before response HTTP POST to ', $apHttpConverterUrl)"/>
      </dp:aaa-log>
      <dp:url-open target="{$apHttpConverterUrl}" response="ignore" http-headers="$httpHeaders">
         <xsl:copy-of select="$envelope"/>
      </dp:url-open>
      <dp:aaa-log priority="debug">
         <xsl:value-of select="concat('*** After response HTTP POST to ', $apHttpConverterUrl)"/>
      </dp:aaa-log>

      <dp:aaa-log priority="debug">
         <xsl:value-of select="'*** Exit handleResponse'"/>
      </dp:aaa-log>
   </xsl:template>
   
   <!--
   identity transform: maintain all element names and values
   -->
   <xsl:template match="@*|node()">
      <xsl:copy>
         <xsl:apply-templates select="@*|node()"/>
      </xsl:copy>
   </xsl:template>
</xsl:stylesheet>
