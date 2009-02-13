<?xml version="1.0"?>

<!--
    Generate a DSA or RSA WS-Security signature.
    This xform is based on the original dp 
    sign-wssec.xsl, with the following modifications:
    * assumes that the message has a MessageID element with a
      wsu:Id attribute.
-->

<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"
  xmlns:date="http://exslt.org/dates-and-times"
  xmlns:dp="http://www.datapower.com/extensions"
  xmlns:dpconfig="http://www.datapower.com/param/config"
  xmlns:dpfunc="http://www.datapower.com/extensions/functions"
  xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd"
  xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd"
  extension-element-prefixes="date dp dpfunc"
  exclude-result-prefixes="date dp dpconfig dpfunc"
>
  <dp:summary xmlns="">
      <operation>sign</operation>
      <description>Generate a DSA or RSA WS-Security signature.</description>
  </dp:summary>

  <xsl:output method="xml"/>

  <xsl:variable name="___soapnsuri___">
    <xsl:choose>
      <xsl:when test="/*[local-name()='Envelope']">
        <xsl:value-of select="namespace-uri(/*)"/>
      </xsl:when>
      <xsl:otherwise>http://schemas.xmlsoap.org/soap/envelope/</xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <dp:dynamic-namespace prefix="soapenv" select="$___soapnsuri___"/>

  <xsl:include href="store:///dp/sign.xsl"/>
  <xsl:include href="store:///utilities.xsl"/>

  <xsl:param name="dpconfig:sigalg" select="'rsa'"/>
  <dp:param name="dpconfig:sigalg" type="dmCryptoSigningAlgorithm" xmlns=""/>

  <xsl:param name="dpconfig:c14nalg" select="'exc-c14n'"/>
  <dp:param name="dpconfig:c14nalg" type="dmCryptoExclusiveCanonicalizationAlgorithm" xmlns="">
    <default>exc-c14n</default>
  </dp:param>

  <xsl:param name="dpconfig:token-reference-mechanism" select="'Direct'"/>
  <dp:param name="dpconfig:token-reference-mechanism" type="dmCryptoWSSTokenReferenceMechanism" xmlns=""/>

  <xsl:param name="dpconfig:wss-x509-token-profile-1.0-binarysecuritytoken-reference-valuetype"
    select="'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-x509-token-profile-1.0#X509v3'"/>
  <dp:param name="dpconfig:wss-x509-token-profile-1.0-binarysecuritytoken-reference-valuetype"
    type="dmCryptoWSSX509TokenProfile10BinarySecurityTokenReferenceValueType" xmlns=""/>

  <xsl:param name="dpconfig:wss-x509-token-profile-1.0-keyidentifier-valuetype"
    select="'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-x509-token-profile-1.0#X509v3SubjectKeyIdentifier'"/>
  <dp:param name="dpconfig:wss-x509-token-profile-1.0-keyidentifier-valuetype"
    type="dmCryptoWSSX509TokenProfile10KeyIdentifierValueType" xmlns=""/>

  <xsl:param name="dpconfig:skitype" select="'pkix'"/>
  <dp:param name="dpconfig:skitype" type="dmCryptoSKIType" xmlns="">
    <description>The form of the Subject Key Identifier to use. This
    parameter is only relevant when the WS-Security Version is 1.0 and
    the Token Reference Mechanism is "KeyIdentifier".</description>
  </dp:param>

  <xsl:param name="dpconfig:wssec-compatibility" select="'1.0'"/>
  <dp:param name="dpconfig:wssec-compatibility" type="dmCryptoWSSecVersion" xmlns=""/>

  <xsl:include href="store:///set-keypair.xsl"/>
  <dp:param name="dpconfig:keypair" type="dmString" xmlns="">
    <display>Key/Certificate Base Name</display>
    <description>The base of the names of the key and certificate to use.  This value is the
    first part of the name used for both the key and certificate.  The end part of the key's
    name is "KEY" and of the certificate's name is "CERT".  For example, enter "foo" if the key
    is named "fooKEY" and the certificate is named "fooCERT".  The base name may be taken from a
    query parameter called "dpquery:keypair" by entering the value "%url%", or from a HTTP
    header named "X-Use-Credentials" by entering the value "X-Use-Credentials".  If the key and
    certificate don't follow the base name naming convention then use the separate Key and
    Certificate parameters instead of this Base Name parameter.</description>
  </dp:param>
  <dp:param name="dpconfig:keypair-key" type="dmReference" reftype="CryptoKey" xmlns="">
      <display>Key</display>
      <description>The key to use.  Setting this overrides any value set in the Key/Certificate
      Base Name.</description>
  </dp:param>
  <dp:param name="dpconfig:keypair-cert" type="dmReference" reftype="CryptoCertificate" xmlns="">
      <display>Certificate</display>
      <description>The certificate to use.  Setting this overrides any value set in the
      Key/Certificate Base Name.</description>
  </dp:param>

  <xsl:param name="dpconfig:include-inline-cert" select="'off'"/>
  <dp:param name="dpconfig:include-inline-cert" type="dmToggle" xmlns="">
    <display>Include Signer's Certificate In-line</display>
    <description>Setting to 'on' causes the signer's certificate to be included in the Signature
    element inside a second KeyInfo block.  This may aid compatibility with certain
    applications.</description>
    <default>off</default>
  </dp:param>

  <xsl:param name="dpconfig:include-second-id" select="'off'"/>
  <dp:param name="dpconfig:include-second-id" type="dmToggle" xmlns="">
    <display>Include Second Id Attribute</display>
    <description>Setting to 'on' causes the output message to include a plain "id" attribute on
    the SOAP Body element in addition to the normal "wsu:Id" attribute.  This may aid
    compatibility with certain applications.</description>
    <default>off</default>
  </dp:param>

  <xsl:param name="dpconfig:include-timestamp" select="'on'"/>
  <dp:param name="dpconfig:include-timestamp" type="dmToggle" xmlns="">
    <display>Include Timestamp</display>
    <description>Setting to 'on', the default, causes the output message to include a Timestamp
    block.</description>
    <default>on</default>
  </dp:param>

  <xsl:param name="dpconfig:timestamp-expiration-period" select="'300'"/>
  <dp:param name="dpconfig:timestamp-expiration-period" type="dmTimeInterval" xmlns="">
    <display>Timestamp Expiration Period</display>
    <units>sec</units>
    <minimum>0</minimum>
    <maximum>31536000</maximum> <!-- 365 days -->
    <default>300</default>
    <description>The expiration period in seconds for the Timestamp (and therefore of the
    security semantics in this signature).  A value of zero (0) means no expiration.  The
    default is 300 seconds (5 minutes).  The maximum is 31536000 seconds (365 days).</description>
  </dp:param>

  <xsl:param name="dpconfig:check-timestamp" select="'on'"/>
  <dp:param name="dpconfig:check-timestamp" type="dmToggle" xmlns="">
    <display>Check Timestamp Expiration</display>
    <description>Setting to 'on', the default, causes an existing Timestamp block to be checked
    for expiration when an expiration time is specified, and the transaction terminated if the
    Timestamp is expired.  Setting to 'off' prevents checking Timestamp
    expiration.</description>
    <default>on</default>
  </dp:param>

  <xsl:param name="dpconfig:timestamp-expiration-override" select="'0'"/>
  <dp:param name="dpconfig:timestamp-expiration-override" type="dmTimeInterval" xmlns="">
    <display>Timestamp Expiration Override Period</display>
    <units>sec</units>
    <minimum>0</minimum>
    <maximum>630720000</maximum> <!-- 20 years -->
    <default>0</default>
    <description>The override expiration period in seconds for the Timestamp checking.  A value of 
    zero (0) means no override.  The default is 0.  The maximum is 630720000 seconds (20 years).
    </description>
  </dp:param>

  <xsl:param name="dpconfig:include-mustunderstand" select="'on'"/>
  <dp:param name="dpconfig:include-mustunderstand" type="dmToggle" xmlns="">
    <display>Include SOAP mustUnderstand</display>
    <description>Setting to 'on', the default, means a SOAP:mustUnderstand="1" attribute is
    included in the wsse:Security header.</description>
    <default>on</default>
  </dp:param>

  <xsl:param name="dpconfig:sign-binarysecuritytoken" select="'off'"/>
  <dp:param name="dpconfig:sign-binarysecuritytoken" type="dmToggle" xmlns="">
    <display>Sign BinarySecurityToken</display>
    <description>If the Token Reference Mechanism is "Direct" then by default
    the inserted BinarySecurityToken is not signed.  Setting this switch to
    'on' causes the BinarySecurityToken to be signed.  In other words, the
    digital signature will cover the BinarySecurityToken along with the other
    signed portions of the message.  Compatibility with certain versions of BEA
    WebLogic may require setting this parameter to 'on'.</description>
    <default>off</default>
  </dp:param>

  <xsl:variable name="wsse-token" select='concat("name:", $pair-cert)'/>

  <!-- If there is an existing Signature element then assume this message is already signed. -->
  <xsl:variable name="existing-security-header"
    select="/*[local-name()='Envelope']/*[local-name()='Header']/*[local-name()='Security'][1]"/>
  <xsl:variable name="existing-signature"
    select="$existing-security-header/*[local-name()='Signature']"/>

  <!-- Determine the version of signature we're creating based on what was configured
       and on any existing Security header.  If there's already a Security header
       present then we must use that version because we don't want to mix versions.
       Plus, if there's an existing signature then it's impossible to put @wsu:Id
       attributes on elements for two different namespace-uris for "wsu" without
       invalidating the existing signature, so we must match namespaces to what
       exists. -->
  <xsl:variable name="wssec-version">
    <xsl:choose>
      <xsl:when test="$existing-security-header">
        <xsl:variable name="existing-security-namespace"
          select="namespace-uri($existing-security-header)"/>
        <xsl:variable name="new-ver">
          <xsl:choose>
            <xsl:when test="$existing-security-namespace='http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd'">
              <xsl:text>1.0</xsl:text>
            </xsl:when>
            <xsl:when test="$existing-security-namespace='http://schemas.xmlsoap.org/ws/2002/07/secext'">
              <xsl:text>draft-12</xsl:text>
            </xsl:when>
            <xsl:when test="$existing-security-namespace='http://schemas.xmlsoap.org/ws/2003/06/secext'">
              <xsl:text>draft-13</xsl:text>
            </xsl:when>
            <xsl:otherwise>
              <xsl:message dp:priority="error" terminate="yes">
                <xsl:text>Unrecognized existing namespace: </xsl:text>
                <xsl:value-of select="string($existing-security-namespace)"/>
              </xsl:message>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:variable>
        <xsl:if test="string($new-ver) != string($dpconfig:wssec-compatibility)">
          <xsl:message>
            <xsl:text>Matching existing namespaces for WS-Security version </xsl:text>
            <xsl:value-of select="$new-ver"/>
            <xsl:text> (</xsl:text><xsl:value-of select="$dpconfig:wssec-compatibility"/><xsl:text> configured)</xsl:text>
          </xsl:message>
        </xsl:if>
        <xsl:value-of select="$new-ver"/>
      </xsl:when>
      <xsl:when test="$dpconfig:wssec-compatibility = '1.0'">
        <xsl:text>1.0</xsl:text>
      </xsl:when>
      <xsl:when test="$dpconfig:wssec-compatibility = 'draft-12'">
        <xsl:text>draft-12</xsl:text>
      </xsl:when>
      <xsl:when test="$dpconfig:wssec-compatibility = 'draft-13'">
        <xsl:text>draft-13</xsl:text>
      </xsl:when>
      <xsl:otherwise>
        <xsl:message>
          <xsl:text>Unrecognized compatibility parameter: </xsl:text>
          <xsl:value-of select="string($dpconfig:wssec-compatibility)"/>
          <xsl:text> (defaulting to 1.0)</xsl:text>
        </xsl:message>
        <xsl:text>1.0</xsl:text>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <xsl:variable name="wsse-uri">
    <xsl:choose>
      <xsl:when test="$wssec-version = '1.0'">
        <xsl:text>http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd</xsl:text>
      </xsl:when>
      <xsl:when test="$wssec-version = 'draft-13'">
        <xsl:text>http://schemas.xmlsoap.org/ws/2003/06/secext</xsl:text>
      </xsl:when>
      <xsl:when test="$wssec-version = 'draft-12'">
        <xsl:text>http://schemas.xmlsoap.org/ws/2002/07/secext</xsl:text>
      </xsl:when>
    </xsl:choose>
  </xsl:variable>

  <xsl:variable name="wsu-uri">
    <xsl:choose>
      <xsl:when test="$wssec-version = '1.0'">
        <xsl:text>http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd</xsl:text>
      </xsl:when>
      <xsl:when test="$wssec-version = 'draft-13'">
        <xsl:text>http://schemas.xmlsoap.org/ws/2003/06/utility</xsl:text>
      </xsl:when>
      <xsl:when test="$wssec-version = 'draft-12'">
        <xsl:text>http://schemas.xmlsoap.org/ws/2002/07/utility</xsl:text>
      </xsl:when>
    </xsl:choose>
  </xsl:variable>

  <dp:dynamic-namespace prefix="wsse" select="$wsse-uri"/>
  <dp:dynamic-namespace prefix="wsu" select="$wsu-uri"/>

  <xsl:variable name="body-copy">
    <!-- Should only be one Body, xsl:for-each allows us to use xsl:copy -->
    <xsl:for-each select="/*[local-name()='Envelope']/*[local-name()='Body'][1]">
      <!-- Copy the Body element so the exact prefix is used in case this message already has a
           signature over the Body; changing the prefix would invalidate the existing
           signature. -->
      <xsl:copy>
        <!-- See if there are any existing @id attributes, including an existing @wsu:Id (this
             may happen when signing an already signed message). -->
        <xsl:variable name="existing-ids"
          select="@*[local-name()='id' or local-name()='Id' or local-name()='ID']"/>
        <xsl:choose>
          <xsl:when test="$existing-ids and $existing-signature">
            <!-- If there are ids present and there's a signature then copy them. Don't change
                 them because the signature, may depend on them. -->
            <xsl:copy-of select="$existing-ids"/>
          </xsl:when>
          <xsl:otherwise>
            <!-- There aren't any id attributes, including no @wsu:Id, so create one -->
            <xsl:variable name="body-id" select="concat('Body-', dp:generate-uuid())"/>
            <xsl:attribute name="wsu:Id">
              <xsl:value-of select="$body-id"/>
            </xsl:attribute>
            <xsl:if test="$dpconfig:include-second-id = 'on'">
              <xsl:attribute name="id">
                <xsl:value-of select="$body-id"/>
              </xsl:attribute>
            </xsl:if>
          </xsl:otherwise>
        </xsl:choose>
        <xsl:copy-of select="@*[local-name()!='id' and local-name()!='Id' and local-name()!='ID']"/>
        <xsl:for-each select="*|text()">
          <xsl:copy-of select='.'/>
        </xsl:for-each>
      </xsl:copy>
    </xsl:for-each>
  </xsl:variable>

  <xsl:template name="create-signature">
    <xsl:param name="existing-timestamp" select="/.."/>
    <wsse:Security>
      <xsl:if test="$dpconfig:include-mustunderstand = 'on'">
        <xsl:attribute name="soapenv:mustUnderstand">1</xsl:attribute>
      </xsl:if>
      <xsl:variable name="timestamp">
        <xsl:if test="$dpconfig:include-timestamp = 'on'">
          <!-- Only add a Timestamp if there isn't already one present -->
          <xsl:if test="not($existing-timestamp/*)">
            <wsu:Timestamp wsu:Id="{concat('Timestamp-', dp:generate-uuid())}">
              <xsl:variable name="now" select="dpfunc:zulu-time()"/>
              <wsu:Created><xsl:value-of select="$now"/></wsu:Created>
              <xsl:if test="$dpconfig:timestamp-expiration-period &gt; 0">
                <wsu:Expires><xsl:value-of
                select="date:add($now, date:duration($dpconfig:timestamp-expiration-period))"/></wsu:Expires>
              </xsl:if>
            </wsu:Timestamp>
          </xsl:if>
        </xsl:if>
      </xsl:variable>
      <xsl:copy-of select="$timestamp/*"/>
      <!-- Build the BinarySecurityToken if doing a Direct reference -->
      <xsl:variable name="bst-id" select="concat('SecurityToken-', dp:generate-uuid())"/>
      <xsl:variable name="BST">
        <xsl:if test="$dpconfig:token-reference-mechanism = 'Direct'">
          <wsse:BinarySecurityToken wsu:Id="{$bst-id}">
            <xsl:choose>
              <xsl:when test="($wssec-version = 'draft-13') or
                              ($wssec-version = 'draft-12')">
                <xsl:attribute name="EncodingType">wsse:Base64Binary</xsl:attribute>
                <xsl:attribute name="ValueType">wsse:X509v3</xsl:attribute>
              </xsl:when>
              <xsl:otherwise>
                <!-- Default to 1.0 -->
                <xsl:attribute name="EncodingType">http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-soap-message-security-1.0#Base64Binary</xsl:attribute>
                <xsl:attribute name="ValueType"><xsl:value-of select="$dpconfig:wss-x509-token-profile-1.0-binarysecuritytoken-reference-valuetype"/></xsl:attribute>
              </xsl:otherwise>
            </xsl:choose>
            <xsl:value-of select="dp:base64-cert($wsse-token)"/>
          </wsse:BinarySecurityToken>
        </xsl:if>
      </xsl:variable>
      <xsl:copy-of select="$BST/*"/>
      <xsl:variable name="BST-for-signing">
        <xsl:if test="$dpconfig:sign-binarysecuritytoken = 'on'">
          <xsl:copy-of select="$BST/*"/>
        </xsl:if>
      </xsl:variable>
      <xsl:call-template name="dp-sign">
        <xsl:with-param name="node" select="$body-copy/*[local-name()='Body'] | $timestamp/* | /*[local-name()='Envelope']/*[local-name()='Header']/*[local-name()='MessageID'] | /*[local-name()='Envelope']/*[local-name()='Header']/*[local-name()='Security']/*[local-name()='Assertion']" />
        <!-- Empty refuri means URIs are pulled from $node -->
        <xsl:with-param name="refuri" select="''"/>
        <xsl:with-param name="keyid" select='concat("name:", $pair-key)'/>
        <xsl:with-param name="certid">
          <xsl:if test="$dpconfig:include-inline-cert = 'on'">
            <xsl:value-of select="concat('name:', $pair-cert)"/>
          </xsl:if>
        </xsl:with-param>
        <xsl:with-param name="sigalg" select='$dpconfig:sigalg'/>
        <xsl:with-param name="c14nalg" select='$dpconfig:c14nalg'/>
        <xsl:with-param name="keyinfo">
          <wsse:SecurityTokenReference>
            <xsl:choose>
              <xsl:when test="$dpconfig:token-reference-mechanism = 'Direct'">
                <wsse:Reference URI="{concat('#', $bst-id)}">
                  <xsl:if test="$wssec-version = '1.0'">
                    <xsl:attribute name="ValueType"><xsl:value-of select="$dpconfig:wss-x509-token-profile-1.0-binarysecuritytoken-reference-valuetype"/></xsl:attribute>
                  </xsl:if>
                </wsse:Reference>
              </xsl:when>
              <xsl:when test="$dpconfig:token-reference-mechanism = 'KeyIdentifier'">
                <wsse:KeyIdentifier>
                  <xsl:if test="$wssec-version = '1.0'">
                    <xsl:attribute name="ValueType"><xsl:value-of select="$dpconfig:wss-x509-token-profile-1.0-keyidentifier-valuetype"/></xsl:attribute>
                    <xsl:attribute name="EncodingType">http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-soap-message-security-1.0#Base64Binary</xsl:attribute>
                  </xsl:if>
                  <xsl:value-of select="dp:get-typed-cert-ski(concat('name:', $pair-cert), $dpconfig:skitype)"/>
                </wsse:KeyIdentifier>
              </xsl:when>
              <xsl:when test="$dpconfig:token-reference-mechanism = 'ThumbPrintSHA1'">
                <wsse:KeyIdentifier
                  ValueType="http://docs.oasis-open.org/wss/oasis-wss-soap-message-security-1.1#ThumbPrintSHA1">
                  <xsl:value-of select="dp:get-cert-thumbprintsha1(concat('name:', $pair-cert))"/>
                </wsse:KeyIdentifier>
              </xsl:when>
            </xsl:choose>
          </wsse:SecurityTokenReference>
        </xsl:with-param>
        <xsl:with-param name="certinfo">
          <xsl:if test="$dpconfig:include-inline-cert = 'on'">
            <!-- Include the exact contents for the 'certid' KeyInfo block here so we can get
                 wsse:SecurityTokenReference in the right namespace. -->
            <xsl:variable name="crt" select="concat('name:', $pair-cert)"/>
            <wsse:SecurityTokenReference>
              <X509Data xmlns="http://www.w3.org/2000/09/xmldsig#">
                <X509Certificate>
                  <xsl:value-of select="dp:base64-cert($crt)"/>
                </X509Certificate>
                <X509IssuerSerial>
                  <X509IssuerName><xsl:value-of select="dp:get-cert-issuer($crt)"/></X509IssuerName>
                  <X509SerialNumber><xsl:value-of select="dp:get-cert-serial($crt)"/></X509SerialNumber>
                </X509IssuerSerial>
              </X509Data>
            </wsse:SecurityTokenReference>
          </xsl:if>
        </xsl:with-param>
      </xsl:call-template>
      <xsl:copy-of select="/*[local-name()='Envelope']/*[local-name()='Header']/*[namespace-uri()=$wsse-uri and local-name()='Security']/*"/>
    </wsse:Security>
  </xsl:template>

  <xsl:template match="/*[local-name()='Envelope']">
    <!-- Initial processing of Timestamp block -->
    <xsl:variable name="existing-timestamp">
      <xsl:variable name="ts" select="$existing-security-header/*[local-name()='Timestamp']"/>
      <xsl:if test="$ts">
        <xsl:variable name="err"
          select="dpfunc:verify-wssec-timestamp($ts, $dpconfig:check-timestamp, $dpconfig:timestamp-expiration-override)"/>
        <xsl:if test="$err != ''">
          <xsl:message dp:priority="error" terminate="yes"><xsl:value-of select="$err"/></xsl:message>
        </xsl:if>
        <!-- If we got here then we didn't terminate processing -->
        <xsl:copy-of select="$ts"/>
      </xsl:if>
    </xsl:variable>

    <soapenv:Envelope>
      <xsl:copy-of select="@*"/>
      <xsl:copy-of select="namespace::*"/>
      <soapenv:Header>
        <xsl:copy-of select="*[local-name()='Header']/@*"/>
        <!-- Must check namespace-uri explicitly because dp:dynamic-namespace only affects
             result nodes and not XPath expressions. -->
        <xsl:copy-of select="*[local-name()='Header']/node()[not(namespace-uri()=$wsse-uri and local-name()='Security')]"/>
        <xsl:call-template name="create-signature">
          <xsl:with-param name="existing-timestamp" select="$existing-timestamp"/>
        </xsl:call-template>
      </soapenv:Header>
      <xsl:copy-of select="$body-copy"/>
    </soapenv:Envelope>
  </xsl:template>

</xsl:stylesheet>
