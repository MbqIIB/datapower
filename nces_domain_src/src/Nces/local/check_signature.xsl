<?xml version="1.0" encoding="ISO-8859-1"?>

<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd"
  xmlns:wsa="http://schemas.xmlsoap.org/ws/2003/03/addressing"
  xmlns:env='http://schemas.xmlsoap.org/soap/envelope'
  xmlns:dp='http://www.datapower.com/extensions'
>

 <!--
	This transform ensures that everything that is supposed
	to be signed is in fact signed.
 -->

 <!--
	Pick up the soap header.
 -->
 <xsl:variable name="header"
    select="/*[local-name()='Envelope']/*[local-name()='Header']"/>

 <!--
	Pick up the security header
 -->
 <xsl:variable name="sec-header"
    select="$header/*[local-name()='Security']"/>

 <!--
	Pick up the signed info element.
 -->
 <xsl:variable name="signed-info"
    select="$sec-header/*[local-name()='Signature']/*[local-name()='SignedInfo']"/>

 <!--
	Pick up the wsu:Id's of all of the message elements that
	should be signed
 -->
 <xsl:variable name="message-id-id"
    select="$header/*[local-name()='MessageID']/@*[local-name()='Id']"/>

 <xsl:variable name="binary-token-id"
    select="$sec-header/*[local-name()='BinarySecurityToken']/@*[local-name()='Id']"/>

 <xsl:variable name="timestamp-id"
    select="$sec-header/*[local-name()='Timestamp']/@*[local-name()='Id']"/>

 <xsl:variable name="saml-id"
    select="$sec-header/*[local-name()='Assertion']/@*[local-name()='Id']"/>

 <xsl:variable name="body-id"
    select="/*[local-name()='Envelope']/*[local-name()='Body']/@*[local-name()='Id']"/>

 <!--
	Pick up the URI's referenced in the signature
 -->
 <xsl:variable name="message-id-sig-uri"
    select="$signed-info/*[local-name()='Reference'][@URI=concat('#', $message-id-id)]"/>

 <xsl:variable name="timestamp-sig-uri"
    select="$signed-info/*[local-name()='Reference'][@URI=concat('#', $timestamp-id)]"/>

 <xsl:variable name="saml-sig-uri"
    select="$signed-info/*[local-name()='Reference'][@URI=concat('#', $saml-id)]"/>

 <xsl:variable name="body-sig-uri"
    select="$signed-info/*[local-name()='Reference'][@URI=concat('#', $body-id)]"/>

  <!--
	This is the template where everything happens,
	Generate a new header with a new MessageID header and all of the remaining headers.
	The add in the soap body.
  -->
  <xsl:template match="/*[local-name()='Envelope']">

	<xsl:choose>
		<xsl:when test="not($message-id-sig-uri)">
			<dp:reject>MessageID element not signed</dp:reject>
		</xsl:when>

		<xsl:when test="not($saml-sig-uri)">
			<dp:reject>SAML Assertion not signed</dp:reject>
		</xsl:when>

		<xsl:when test="not($timestamp-sig-uri)">
			<dp:reject>Timestamp element is not signed</dp:reject>
		</xsl:when>

		<xsl:when test="not($body-sig-uri)">
			<dp:reject>Body element is not signed</dp:reject>
		</xsl:when>

		<xsl:otherwise>
			<xsl:copy-of select="."/>
		</xsl:otherwise>
	</xsl:choose>

  </xsl:template>

</xsl:stylesheet>



