<?xml version="1.0" encoding="ISO-8859-1"?>

<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd"
  xmlns:wsa="http://schemas.xmlsoap.org/ws/2003/03/addressing"
  xmlns:env='http://schemas.xmlsoap.org/soap/envelope'
  xmlns:dp='http://www.datapower.com/extensions'
>

 <!--
	This transform ensures that there is a message id in a soap message
	and that it has a wsu:Id attribute. If a message comes in with
	a MessageID that has an existing wsu:Id attribute, this xform will
	change the wsu:Id id.
 -->

 <!--
	Pick up the soap header.
 -->
 <xsl:variable name="header"
    select="/*[local-name()='Envelope']/*[local-name()='Header']"/>


  <!--
	Pick up the existing message id text. This is just the actual id
	text without any of the elements.
  -->
  <xsl:variable name="existing-message-id"
    select="$header/*[local-name()='MessageID']/text()"/>


  <!--
	Set the message id text (i.e. the actual id) to either the
	existing id or a new id that we make up
  -->
  <xsl:variable name="message-id-text">
    <xsl:choose>
      <xsl:when test="$existing-message-id">
      		<xsl:value-of select="$existing-message-id"/>
      </xsl:when>
      <xsl:otherwise>
        	<xsl:value-of select="dp:generate-uuid()"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <!--
	Pick up all of the other (i.e. non-MessageID) headers.
  -->
  <xsl:variable name="other-headers">
	<xsl:for-each select="$header/*[local-name()!='MessageID' and local-name()!='other']">
		<xsl:copy-of select="." />
	</xsl:for-each>
  </xsl:variable>


  <!--
	This is the template where everything happens,
	Generate a new header with a new MessageID header and all of the remaining headers.
	The add in the soap body.
  -->
  <xsl:template match="/*[local-name()='Envelope']">
	<xsl:copy>

	<env:Header>
		<wsa:MessageID wsu:Id="msgid-{generate-id()}">
			<xsl:value-of select="$message-id-text"/>
		</wsa:MessageID>
		<xsl:copy-of select="$other-headers"/>
	</env:Header>
	<xsl:copy-of select="/*[local-name()='Envelope']/*[local-name()='Body']"/>
	</xsl:copy>
  </xsl:template>

</xsl:stylesheet>



