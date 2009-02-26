<?xml version="1.0" encoding="UTF-8" ?>
<!--
  Licensed Materials - Property of IBM
  IBM WebSphere DataPower Appliances
  Copyright IBM Corporation 2007. All Rights Reserved.
  US Government Users Restricted Rights - Use, duplication or disclosure
  restricted by GSA ADP Schedule Contract with IBM Corp.
-->

<!--
/*
 *
 *   Copyright (c) 2002-2003 DataPower Technology, Inc. All Rights Reserved
 *
 * THIS IS UNPUBLISHED PROPRIETARY TRADE SECRET SOURCE CODE OF DataPower
 * Technology, Inc.
 *
 * The copyright above and this notice must be preserved in all copies of
 * the source code. The copyright notice above does not evidence any actual
 * or intended publication of such source code. This source code may not be
 * copied, compiled, disclosed, distributed, demonstrated or licensed except
 * as expressly authorized by DataPower Technology, Inc.
 *
 */
-->

<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:dpgui="http://www.datapower.com/extensions/webgui"
    xmlns:dp="http://www.datapower.com/extensions" 
    xmlns:dpfunc="http://www.datapower.com/extensions/functions"
    xmlns:func="http://exslt.org/functions"
    xmlns:regexp="http://exslt.org/regular-expressions"
    extension-element-prefixes="dp func regexp"
    exclude-result-prefixes="dpgui">

    <!-- this file contains the stylesheets which convert XML to CLI scripts -->
    
    <xsl:include href="SchemaUtil.xsl"/>
   
    <xsl:output method="text" encoding="utf-8" indent="yes"/>
    
    <!-- Note this is for compilation purposes only.  The real sessionid
         is set in main.xsl, modify.xsl and drMgmtInterface.xsl.  Therefore,
         you must always import (not include) clixform.xsl
    <xsl:variable name="sessionid" select="'undefined-in-clixform'"/>
    -->

    <func:function name="dpfunc:if-then-else">
        <xsl:param name="condition" />
        <xsl:param name="ifValue" />
        <xsl:param name="elseValue"></xsl:param>
        
        <xsl:choose>
            <xsl:when test="$condition">
                <func:result select="$ifValue" />
            </xsl:when>
            <xsl:otherwise>
                <func:result select="$elseValue" />
            </xsl:otherwise>
        </xsl:choose>
    </func:function>

    <xsl:variable name="eol">
        <xsl:text>&#xA;</xsl:text>
    </xsl:variable>
    
    <xsl:variable name="quote">
        <xsl:text>"</xsl:text>
    </xsl:variable>

    <!-- for dynamic config generation, we need to know if an object already exists,
         so it can be deleted first.  When we're generating a startup-config script,
         however, we never do this.  So the solution is to fetch the current config only
         when we're doing dynamic config, and leave this an empty node-set otherwise. -->

    <!-- we are doing a delta, as opposed to generating an entire config 
         as used by 'show running config' and 'show mem' -->
    <xsl:variable name="delta-config" 
        select="(/request/args/action = 'save' or /request/args/action='configUpDate')"/>

    <xsl:variable name="cli-existing">
        <!-- in either save-config or show-config mode, don't generate 'no' statements -->
        <xsl:if test="($delta-config=true())">
            <xsl:choose>
                <xsl:when test="function-available('dpgui:get-config')">
                    <xsl:call-template name="do-mgmt-request">
                        <xsl:with-param name="request">
                            <request>
                              <operation type="get-config"/>
                            </request>
                        </xsl:with-param>
                    </xsl:call-template>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:message> Warning: simulating get-config for cli-existing in clixform.xsl </xsl:message>
                    <!-- for debugging delta updates with xj:
                         use a request document as input (see debug/request.xml)
                         and retrieve a canned 'cli-existing' file here -->
                    <xsl:copy-of select="document('debug/cfg.xml')"/>    
                </xsl:otherwise>
            </xsl:choose>
        </xsl:if>
    </xsl:variable>

    <!-- for use with 'show running-config', 'write-mem' from CLI 
         and save-config from WebGUI -->
    <xsl:template match="/" priority="-100">      
      <!--<xsl:if test="false()">
          <dp:dump-nodes file="'clixform-input.xml'" nodes="/"/>
      </xsl:if> -->
      <xsl:value-of select="concat('configure terminal', $eol, $eol)"/>      
      <xsl:apply-templates mode="cli-object" select="*"/>
    </xsl:template>

    <!-- utility template -->
    <xsl:template mode="cli-object" match="configuration">
        <xsl:call-template name="version-comment"/>        
        <xsl:apply-templates mode="cli-object" select="*"/>
    </xsl:template>

    <xsl:template name="version-comment">
        <!-- context node is /configuration -->
        <xsl:if test="(@build and @timestamp)">
            <xsl:text># configuration generated </xsl:text>
            <xsl:value-of select="normalize-space(@timestamp)"/>
            <xsl:text>; firmware version </xsl:text>
            <xsl:value-of select="normalize-space(@build)"/>
        </xsl:if>
    </xsl:template>

    <!-- ======== cli-object and cli-delete-object templates begin here ======== -->
    
    <!-- ************************************************************ -->
    <!-- EthernetInterface -->
    <!-- ************************************************************ -->
    <xsl:template name="EthernetInterfaceDelete">
        <xsl:param name="interface"/>
        <!-- There is no 'no interface' commmand, delete properties individually -->
        <xsl:value-of select="concat($eol, 'interface ', dpfunc:quoesc($interface), $eol)"/>
        <xsl:value-of select="concat('  admin-state disabled', $eol)"/>
        <xsl:value-of select="concat('  no standby', $eol)"/>
        <!-- 'clear route' whacks all static routes and also the default gateway -->
        <xsl:value-of select="concat('  clear route', $eol)"/>
        <xsl:value-of select="concat('  no dhcp', $eol)"/>
        <xsl:value-of select="concat('  no ip secondary', $eol)"/>
        <xsl:value-of select="concat('  arp', $eol)"/>
        <xsl:value-of select="concat('  mode auto', $eol)"/>
        <xsl:value-of select="concat('  no ip address', $eol)"/>
        <xsl:value-of select="concat('exit ', $eol)"/>
    </xsl:template>

    <xsl:template mode="cli-delete-object" match="EthernetInterface">
        <xsl:call-template name="EthernetInterfaceDelete">
            <xsl:with-param name="interface" select="@name"/>
        </xsl:call-template>
    </xsl:template>

    <xsl:template mode="cli-object" match="EthernetInterface">
        <!-- not dynamic delete properties individually -->
        <xsl:if test="($delta-config=true())">
            <xsl:call-template name="EthernetInterfaceDelete">
                <xsl:with-param name="interface" select="@name"/>
            </xsl:call-template>
        </xsl:if>

        <xsl:value-of select="concat($eol, 'interface ', dpfunc:quoesc(@name), $eol)"/>
        <!-- 'admin-state enabled' is not written because defaults are skipped. Force it -->
        <xsl:if test="(string(mAdminState) = 'enabled')">
            <xsl:value-of select="concat('  admin-state ',dpfunc:quoesc(mAdminState), $eol)"/>
        </xsl:if>
        <xsl:apply-templates mode="EthernetInterface"/>
        <xsl:value-of select="concat('exit ', $eol)"/>
    </xsl:template>

    <xsl:template mode="EthernetInterface" match="SecondaryAddress">
        <xsl:value-of select="concat('  ip address ', text(), ' secondary', $eol )"/>
    </xsl:template>
    
    <xsl:template mode="EthernetInterface" match="StaticRoutes">
        <xsl:choose>
            <xsl:when test="number(Metric) &gt; 0">
                <xsl:value-of select="concat('  ip route ', Destination, ' ', Gateway, ' ', Metric, $eol )"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="concat('  ip route ', Destination, ' ', Gateway, $eol )"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <!-- StandbyControls -->
    <xsl:template mode="EthernetInterface" match="StandbyControls">
        <xsl:value-of select="concat('  standby ', Group, ' ip ', VirtualIP, $eol)"/>
        <xsl:value-of select="concat('  standby ', Group, ' priority ', Priority, $eol)"/>
        <xsl:value-of select="concat('  standby ', Group, ' preempt ', Preempt, $eol)"/>
        <xsl:value-of select="concat('  standby ', Group, ' auth ', AuthHigh, ' ', AuthLow, $eol)"/>
        <xsl:value-of select="concat('  standby ', Group, ' timers ', HelloTimer, ' ', HoldTimer, $eol)"/>

	    <xsl:if test="string(AuxVirtualIP)">
		  <xsl:value-of select="concat('  standby ', Group, ' ip-aux ', string(AuxVirtualIP), $eol)"/>
		</xsl:if>
    </xsl:template>
    
    <xsl:template mode="EthernetInterface" match="UseARP">
        <xsl:choose>
            <xsl:when test="text()='off'">
                <xsl:value-of select="concat('  no arp', $eol )"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="concat('  arp', $eol )"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <xsl:template mode="EthernetInterface" match="MTU">
        <xsl:value-of select="concat('  mtu ', text(), $eol)"/>
    </xsl:template>
    
    <xsl:template mode="EthernetInterface" match="InterfaceIndex"/>
    
    <xsl:template mode="EthernetInterface" match="*">
        <xsl:apply-templates mode="CanonicalProperty" select="."/>
    </xsl:template>
    
    <!-- ************************************************************ -->
    <!-- CRLFetch -->
    <!-- ************************************************************ -->
    <xsl:template mode="cli-delete-object" match="CRLFetch"/>
    
    <xsl:template mode="cli-object" match="CRLFetch">
        <xsl:call-template name="CryptoWrapper">
            <xsl:with-param name="cmdline">
                <xsl:value-of select="concat('no crl' , $eol )"/>
                <xsl:apply-templates mode="CRLFetch"/>
            </xsl:with-param>
        </xsl:call-template>
    </xsl:template>

    <xsl:template mode="CRLFetch" match="CRLFetchConfig">
        <xsl:value-of select="concat('  crl ', dpfunc:quoesc(Name), ' ', FetchType, $eol)"/>
        <xsl:apply-templates mode="CRLFetchConfig"/>
        <xsl:value-of select="concat('  exit', $eol)"/>
    </xsl:template>

    <xsl:template mode="CRLFetchConfig" match="IssuerValcred">
        <xsl:value-of select="concat('    issuer ', text(), $eol )"/>
    </xsl:template>
    
    <xsl:template mode="CRLFetchConfig" match="RefreshInterval">
        <xsl:value-of select="concat('    refresh ', text(), $eol )"/>
    </xsl:template>
    
    <xsl:template mode="CRLFetchConfig" match="DefaultStatus">
        <xsl:value-of select="concat('    default-status ', text(), $eol )"/>
    </xsl:template>
    
    <xsl:template mode="CRLFetchConfig" match="CryptographicProfile[text()!='']">
        <xsl:value-of select="concat('    ssl-profile ', text(), $eol )"/>
    </xsl:template>
    
    <xsl:template mode="CRLFetchConfig" match="URL[../FetchType='http']">
        <xsl:value-of select="concat('    fetch-url ', dpfunc:quoesc(text()), $eol )"/>
    </xsl:template>
    
    <xsl:template mode="CRLFetchConfig" match="RemoteAddress[../FetchType='ldap']">
        <xsl:value-of select="concat('    remote-address ', text(), ' ', ../RemotePort, $eol )"/>
    </xsl:template>
    
    <xsl:template mode="CRLFetchConfig" match="DN[../FetchType='ldap']">
        <xsl:value-of select="concat('    read-dn ', dpfunc:quoesc(text()), $eol )"/>
    </xsl:template>
    
    <xsl:template mode="CRLFetchConfig" match="BindDN[../FetchType='ldap']">
        <xsl:value-of select="concat('    bind-dn ', dpfunc:quoesc(text()), $eol )"/>
    </xsl:template>
    
    <xsl:template mode="CRLFetchConfig" match="BindPass[../FetchType='ldap']">
        <xsl:value-of select="concat('    bind-pass ', dpfunc:quoesc(text()), $eol )"/>
    </xsl:template>
    
    <xsl:template mode="CRLFetchConfig" match="*"/>

    <!-- ************************************************************ -->
    <!-- TimeSettings -->
    <!-- ************************************************************ -->
    <xsl:template mode="cli-object" match="TimeSettings[LocalTimeZone]">

        <xsl:call-template name="available-open">
            <xsl:with-param name="name" select="local-name()"/>
        </xsl:call-template>

        <xsl:value-of select="concat($eol, 'timezone ', LocalTimeZone)"/>
        <xsl:if test="(LocalTimeZone='Custom')">
            <xsl:value-of select="concat(' ', CustomTZName, ' ', UTCDirection, ' ',
                                  OffsetHours, ' ', OffsetMinutes)"/>
            <xsl:apply-templates mode="TimeSettings" select="."/>
        </xsl:if>
        <xsl:value-of select="$eol"/>

        <xsl:call-template name="available-close">
            <xsl:with-param name="name" select="local-name()"/>
        </xsl:call-template>

    </xsl:template>

    <xsl:template mode="TimeSettings" match="TimeSettings[DaylightOffsetHours >= 0]">
        <xsl:value-of select="concat(' ', DaylightOffsetHours, ' ',
                              TZNameDST, ' ', DaylightStartMonth, ' ', DaylightStartWeek, ' ',
                              DaylightStartDay, ' ', DaylightStartTimeHours, ' ', 
                              DaylightStartTimeMinutes, ' ', 
                              DaylightStopMonth, ' ', DaylightStopWeek, ' ',
                              DaylightStopDay, ' ', DaylightStopTimeHours, ' ', 
                              DaylightStopTimeMinutes)"/>
    </xsl:template>

    <xsl:template mode="TimeSettings" match="TimeSettings"/>

    <!-- ************************************************************ -->
    <!-- StylePolicy -->
    <!-- ************************************************************ -->
    <xsl:template mode="cli-object" match="StylePolicy">
        <xsl:value-of select="concat($eol, 'stylepolicy ', dpfunc:quoesc(@name), $eol)"/>
        <xsl:if test="($delta-config=true())">
            <xsl:value-of select="concat('  reset', $eol)"/>
        </xsl:if>
        <xsl:apply-templates mode="StylePolicy"/>
        <xsl:value-of select="concat('exit', $eol )"/>
    </xsl:template>

    <!-- if the rule is local, express it inline -->
    <xsl:template mode="StylePolicy" match="PolicyMaps">
        <xsl:variable name="configuration" select="../.."/>

        <!-- the name of the referenced rule -->
        <xsl:variable name="ruleName" select="Rule"/>
        <!-- referenced rule -->
        <xsl:variable name="theRule">
            <xsl:choose>
                <!-- first look in the context document -->
                <xsl:when test="($configuration/StylePolicyRule[@name=$ruleName])">
                    <xsl:copy-of select="$configuration/StylePolicyRule[@name=string($ruleName)]"/>
                </xsl:when>
                <!-- or if delta-config, look for existing object -->
                <xsl:when test="($delta-config)">
                    <xsl:copy-of select="$cli-existing//configuration/StylePolicyRule[@name=$ruleName]"/>
                </xsl:when>
            </xsl:choose>
        </xsl:variable>

        <xsl:choose>
            <!-- if local -->
            <xsl:when test="($theRule/StylePolicyRule/@local='true')">
                <!-- inline rule definition -->
                <xsl:value-of select="concat('  ', $theRule/StylePolicyRule/Direction, ' ', Match, $eol)"/>

                <!-- NB: we need to pass a pointer to the configuration element in the 
                     input document. since we are calling apply-templates on an RTF, 
                     recursive templates can no longer use the ancestor access to get 
                     the input doc. instead, they can use the $configuration node
                     -->
                <xsl:apply-templates mode="StylePolicyRule" select="$theRule/StylePolicyRule/*">
                    <xsl:with-param name="configuration" select="$configuration"/>
                </xsl:apply-templates>

                <xsl:value-of select="concat('  exit', $eol)"/>
            </xsl:when>
            <!-- if global -->
            <xsl:otherwise>
                <!-- reference rule object -->
                <xsl:value-of select="concat('  match ', dpfunc:quoesc(Match), ' ', dpfunc:quoesc(Rule), $eol)"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <xsl:template mode="StylePolicy" match="*">
        <xsl:apply-templates mode="CanonicalProperty" select="."/>
    </xsl:template>

    <!-- ************************************************************ -->
    <!-- TCPProxyService -->
    <!-- ************************************************************ -->
    <xsl:template mode="cli-object" match="TCPProxyService">
        <xsl:value-of select="concat($eol, 'tcpproxy ', dpfunc:quoesc(@name), ' ', LocalAddress,
                              ' ', LocalPort, ' ', RemoteAddress, ' ', RemotePort)"/>
        <xsl:if test="(Priority != 'normal')">
          <xsl:value-of select="concat(' ', Priority)"/>
        </xsl:if>
        <xsl:value-of select="$eol"/>
    </xsl:template>

    <!-- ************************************************************ -->
    <!-- SSLProxyService -->
    <!-- ************************************************************ -->
    <xsl:template mode="cli-object" match="SSLProxyService">
        <xsl:value-of select="concat($eol, 'sslforwarder ', dpfunc:quoesc(@name), ' ', LocalAddress,
                                     ' ', LocalPort, ' ', RemoteAddress, ' ', RemotePort,
                                     ' ', SSLProxy)"/>
        <xsl:if test="(Priority != 'normal')">
          <xsl:value-of select="concat(' ', Priority)"/>
        </xsl:if>
        <xsl:value-of select="$eol"/>
    </xsl:template>

    <!-- ************************************************************ -->
    <!-- URLRefreshPolicy -->
    <!-- ************************************************************ -->
    <xsl:template mode="cli-object" match="URLRefreshPolicy">
        <xsl:value-of select="concat($eol, 'urlrefresh ', dpfunc:quoesc(@name), $eol)"/>
        <xsl:if test="($delta-config=true())">
            <xsl:value-of select="concat('  reset', $eol)"/>
        </xsl:if>
        <xsl:apply-templates mode="URLRefreshPolicy"/>
        <xsl:value-of select="concat('exit', $eol)"/>
    </xsl:template>

    <xsl:template mode="URLRefreshPolicy" match="URLRefreshRule">
        <xsl:choose>
            <xsl:when test="URLRefreshPolicy='no-flush'">
                <xsl:value-of select="concat('  disable flush ', dpfunc:quoesc(URLMap), ' ', URLRefreshInterval, $eol)"/>
            </xsl:when>
            <xsl:when test="URLRefreshPolicy='no-cache'">
                <xsl:value-of select="concat('  disable cache ', dpfunc:quoesc(URLMap), ' ', $eol)"/>
            </xsl:when>
            <xsl:when test="URLRefreshPolicy='protocol-specified'">
                <xsl:value-of select="concat('  protocol-specified ', dpfunc:quoesc(URLMap), ' ', URLRefreshInterval, $eol)"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="concat('  interval urlmap ', dpfunc:quoesc(URLMap), ' ', URLRefreshInterval, $eol)"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <xsl:template mode="URLRefreshPolicy" match="*">
        <xsl:apply-templates mode="DefaultProperty" select=".">
            <xsl:with-param name="objName" select="name(..)"/>
            <xsl:with-param name="pName" select="name()"/>
            <xsl:with-param name="pValue" select="."/>
        </xsl:apply-templates>
    </xsl:template>

    <!-- ************************************************************ -->
    <!-- XMLManager -->
    <!-- ************************************************************ -->
    <xsl:template mode="cli-object" match="XMLManager">
        <!-- if not marked as having been deleted -->
        <xsl:if test="not(@deleted='true')">
            <!-- if xmlmgr already existed, this will only re-enable it -->
            <xsl:value-of select="concat($eol, 'xmlmgr ',  dpfunc:quoesc(@name))"/>
            <xsl:if test="(SSLProxy != '')">
                <xsl:value-of select="concat(' ssl ',  dpfunc:quoesc(SSLProxy))"/>
            </xsl:if>
            <xsl:value-of select="$eol"/>

            <xsl:if test="($delta-config=true())">
                <!-- Remove associated URL refresh policy -->
                <xsl:value-of select="concat($eol, 'no xslrefresh ', dpfunc:quoesc(@name), $eol)"/>
                <!-- Remove all xpath function maps -->
                <xsl:value-of select="concat($eol, 'no xpath function map ', dpfunc:quoesc(@name), $eol)"/>
                <xsl:value-of select="concat($eol, 'no xslconfig ', dpfunc:quoesc(@name), $eol)"/>
            </xsl:if>

            <!-- remaining properties are set outside -->
            <xsl:apply-templates mode="XMLManager"/>

            <xsl:value-of select="concat($eol,'xml parser limits ', dpfunc:quoesc(@name), $eol)"/>
            <xsl:if test="($delta-config=true())">
              <xsl:value-of select="concat('  reset', $eol)"/>
            </xsl:if>
            <xsl:apply-templates mode="ParserLimits"/>
            <xsl:value-of select="concat('exit', $eol)"/>

            <xsl:value-of select="concat($eol,'documentcache ', dpfunc:quoesc(@name), $eol)"/>
            <xsl:value-of select="concat(' no policy', $eol)"/>
            <xsl:apply-templates mode="DocumentCache"/>
            <xsl:value-of select="concat('exit', $eol)"/>
            
            <xsl:value-of select="concat('no xml validate ',
                                         dpfunc:quoesc(@name),
                                         ' *', $eol)"/>
            <xsl:apply-templates mode="SchemaValidation"
                                 select="SchemaValidation"/>

            <!-- new age XML Manager configuration -->
            <xsl:value-of select="concat($eol, 'xml-manager ', dpfunc:quoesc(@name), $eol)"/>
            <xsl:if test="($delta-config=true())">
                <xsl:value-of select="concat('  admin-state enabled',$eol)"/>
                <xsl:value-of select="concat('  no schedule-rule', $eol)"/>
                <xsl:value-of select="concat('  no loadbalancer-group', $eol)"/>
            </xsl:if>
            <!-- if there's none specified, then don't remove the default -->
            <xsl:if test="not(UserAgent)">
                <xsl:value-of select="concat('  user-agent default', $eol)"/>
            </xsl:if>
            <xsl:apply-templates mode="XMLManagerCanonical"/>
            <xsl:value-of select="concat('exit', $eol)"/>

        </xsl:if>
    </xsl:template>

    <xsl:template mode="XMLManager" match="ExtensionFunctions">
        <xsl:value-of select="concat('xpath function map ', dpfunc:quoesc(../@name), 
                              ' {', ExtensionFunctionNamespace, '}', ExtensionFunction,
                              ' {', LocalFunctionNamespace, '}', LocalFunction, $eol)"/>
    </xsl:template>
    
    <xsl:template mode="XMLManager" match="URLRefreshPolicy">
        <xsl:if test="text()!=''">
            <xsl:value-of select="concat('xslrefresh ', dpfunc:quoesc(../@name), ' ', dpfunc:quoesc(text()), $eol)"/>
        </xsl:if>
    </xsl:template>

    <xsl:template mode="XMLManager" match="CompileOptionsPolicy">
        <xsl:if test="text()!=''">
            <xsl:value-of select="concat('xslconfig ', dpfunc:quoesc(../@name), ' ', dpfunc:quoesc(text()), $eol)"/>
        </xsl:if>
    </xsl:template>
    
    <xsl:template mode="XMLManager" match="CacheSize">
        <xsl:if test="text()!=''">
            <xsl:value-of select="concat('xsl cache size ', dpfunc:quoesc(../@name), ' ', text(), $eol)"/>
        </xsl:if>
    </xsl:template>

    <xsl:template mode="XMLManager" match="Profiling">
        <xsl:if test="text()!=''">
          <xsl:value-of select="concat('xsl profile ', dpfunc:quoesc(../@name))"/>
        </xsl:if>
    </xsl:template>

    <xsl:template mode="XMLManager" match="SHA1Caching">
        <xsl:if test="(text()='off')">
            <xsl:value-of select="'no '"/>
        </xsl:if>
        <xsl:value-of select="concat('xsl checksummed cache ', ../@name, $eol)"/>
    </xsl:template>
    
    <!-- 'xml parser limits' sub menu -->
    <xsl:template mode="XMLManager" match="ParserLimitsAttributeCount
                                           |ParserLimitsBytesScanned
                                           |ParserLimitsElementDepth
                                           |ParserLimitsMaxNodeSize
                                           |ParserLimitsForbidExternalReferences
                                           |ParserLimitsExternalReferences
                                           |ParserLimitsAttachmentByteCount
                                           |ParserLimitsAttachmentPackageByteCount"/>

    <xsl:template mode="ParserLimits" match="ParserLimitsAttributeCount
                                             |ParserLimitsBytesScanned
                                             |ParserLimitsElementDepth
                                             |ParserLimitsMaxNodeSize
                                             |ParserLimitsForbidExternalReferences
                                             |ParserLimitsExternalReferences
                                             |ParserLimitsAttachmentByteCount
                                             |ParserLimitsAttachmentPackageByteCount">
      <xsl:apply-templates mode="DefaultProperty" select=".">
            <xsl:with-param name="objName" select="name(..)"/>
            <xsl:with-param name="pName" select="name()"/>
            <xsl:with-param name="pValue" select="."/>
      </xsl:apply-templates>
    </xsl:template>
    
    <!-- 'documentcache' sub menu; can't use generic templates since 'reset' isn't emitted
         name and showNameInput are gui junk -->
    <xsl:template mode="XMLManager" match="DocCacheMaxDocs|DocCacheSize|StaticDocumentCalls|DocCachePolicy|name|showNameInput" />

    <xsl:template mode="DocumentCache" match="DocCacheMaxDocs">
        <xsl:value-of select="concat(' maxdocs ', dpfunc:quoesc(.), $eol)"/>
    </xsl:template>
    <xsl:template mode="DocumentCache" match="DocCacheSize">
        <xsl:value-of select="concat(' size ', dpfunc:quoesc(.), $eol)"/>
    </xsl:template>

    <!-- this one uses an abnormal form; suppress default 'on' value  -->
    <xsl:template mode="DocumentCache" match="StaticDocumentCalls">
        <xsl:if test="($delta-config=true() or text()='off')">
            <xsl:value-of select="concat(' static-document-calls ', text(), $eol)"/>
        </xsl:if>
    </xsl:template>

    <xsl:template mode="DocumentCache" match="DocCachePolicy">
        <xsl:value-of select="concat(' policy ', dpfunc:quoesc(Match), ' ', dpfunc:quoesc(Priority), ' ')"/>
        <xsl:choose>
            <!-- type 'no-cache' expressed through 'nocache' in CLI -->
            <xsl:when test="(Type = 'no-cache')">
                <xsl:value-of select="concat('nocache', $eol)"/>
            </xsl:when>
            <!-- type 'protocol' expressed through no TTL value in CLI -->
            <xsl:when test="(Type = 'protocol')">
                <xsl:value-of select="$eol"/>
            </xsl:when>
            <!-- type 'fixed' -->
            <xsl:otherwise>
                <xsl:value-of select="concat(TTL, $eol)"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <xsl:template mode="XMLManager" match="SchemaValidation"/>
    <xsl:template mode="SchemaValidation" match="SchemaValidation">
      <xsl:value-of select="concat('xml validate ', dpfunc:quoesc(../@name),
                                   ' ', dpfunc:quoesc(Matching))"/>
      <xsl:choose>
        <xsl:when test="ValidationMode = 'schema'">
          <xsl:value-of select="concat(' schema ', SchemaURL)"/>
        </xsl:when>
        <xsl:when test="ValidationMode = 'dynamic-schema'">
          <xsl:value-of select="concat(' dynamic-schema ',
                                       dpfunc:quoesc(DynamicSchema))"/>
        </xsl:when>
        <xsl:when test="ValidationMode = 'attribute-rewrite'">
          <xsl:value-of select="concat(' attribute-rewrite ',
                                       dpfunc:quoesc(URLRewritePolicy))"/>
        </xsl:when>
        <xsl:when test="ValidationMode = 'schema-rewrite'">
          <xsl:value-of select="concat(' schema-rewrite ',
                                       dpfunc:quoesc(SchemaURL),
                                       ' ', dpfunc:quoesc(URLRewritePolicy))"/>
        </xsl:when>
        <xsl:when test="ValidationMode = 'default'">
            <!-- nothing to add to the command line here. -->
        </xsl:when>
      </xsl:choose>
      <xsl:value-of select="$eol"/>
    </xsl:template>
    
    <!-- suppress schedule-rule in XMLManager mode and handle in Canonical mode -->
    <xsl:template mode="XMLManager" match="ScheduledRule"/>
    <xsl:template mode="XMLManagerCanonical" match="ScheduledRule">
        <xsl:value-of select="concat('  schedule-rule ', dpfunc:quoesc(Rule), ' ', Interval, $eol)"/>
    </xsl:template>
    
    <!-- suppress loadbalancer-group in XMLManager mode and handle in Canonical mode -->
    <xsl:template mode="XMLManager" match="VirtualServers"/>
    <xsl:template mode="XMLManagerCanonical" match="VirtualServers">
        <xsl:if test=". and (string(.) != '')">
            <xsl:value-of select="concat('  loadbalancer-group ', dpfunc:quoesc(.) , $eol)"/>
        </xsl:if>
    </xsl:template>

    <!-- xmlmgr has no 'reset' - do manually or default can not be  restored -->
    <xsl:template mode="XMLManager" match="UserAgent"/>
    <xsl:template mode="XMLManagerCanonical" match="UserAgent">
      <xsl:if test=". and (string(.) != '')">
        <xsl:value-of select="concat('  user-agent ', dpfunc:quoesc(.) , $eol)"/>
      </xsl:if>
    </xsl:template>

    <!-- suppress admin-state and user-summary .. and do in Canonical mode -->
    <xsl:template mode="XMLManager" match="mAdminState|UserSummary"/>
    <xsl:template mode="XMLManagerCanonical" match="UserSummary|mAdminState">
        <xsl:apply-templates mode="CanonicalProperty" select="."/>
    </xsl:template>

    <!-- the troublesome global match that forces all the above suppressions -->
    <xsl:template mode="XMLManager" match="*">
        <xsl:apply-templates mode="CanonicalProperty" select="."/>
    </xsl:template>

    <!-- ************************************************************ -->
    <!-- XSLProxyService -->
    <!-- ************************************************************ -->  
    
    <xsl:template mode="cli-object" match="XSLProxyService">
        <!-- XSL proxy menu properties -->
        <xsl:value-of select="concat($eol, 'xslproxy ', dpfunc:quoesc(@name), $eol)"/>
        <xsl:if test="($delta-config=true())">
            <xsl:value-of select="concat('  reset', $eol)"/>
        </xsl:if>
        <xsl:apply-templates mode="XSLProxyService"/>
        <xsl:value-of select="concat('exit', $eol )"/>
        <!-- HTTP proxy menu properties -->
        <xsl:call-template name="HTTPProxyServiceProperties">
            <xsl:with-param name="identifier" select="'xslproxy'"/>
        </xsl:call-template>
    </xsl:template>
    
    <!-- Dispatch from mode XSLProxyService or XMLFirewallService to the common leaf templates -->

    <xsl:template mode="XSLProxyService" match="LocalAddress
                                                |Type[text()='static-backend']
                                                |Type[text()='loopback-proxy']
                                                |Type[text()='dynamic-backend']
                                                |Type[text()='strict-proxy']
                                                |StylesheetParameters">
        <xsl:apply-templates mode="ProxyService" select="."/>
    </xsl:template>

    <xsl:template mode="XMLFirewallService" match="LocalAddress
                                                    |Type[text()='static-backend']
                                                    |Type[text()='loopback-proxy']
                                                    |Type[text()='dynamic-backend']
                                                    |Type[text()='strict-proxy']
                                                    |StylesheetParameters">
        <xsl:apply-templates mode="ProxyService" select="."/>
    </xsl:template>

    <xsl:template mode="XSLProxyService" match="*[starts-with(local-name(),'StylesheetParameter_name_')]">
        <xsl:call-template name="ProxyService_StylesheetParameter_name"/>
    </xsl:template>

    <xsl:template mode="XMLFirewallService" match="*[starts-with(local-name(),'StylesheetParameter_name_')]">
        <xsl:call-template name="ProxyService_StylesheetParameter_name"/>
    </xsl:template>

    <xsl:template mode="XSLProxyService" match="ACL">
        <xsl:apply-templates mode="ProxyService" select="."/>
    </xsl:template>

    <xsl:template mode="XMLFirewallService" match="ACL">
        <xsl:apply-templates mode="ProxyService" select="."/>
    </xsl:template>

    <!-- Common code -->

    <xsl:template name="ProxyService_StylesheetParameter_name">
        <xsl:if test=". and (string(.) != '')">
            <xsl:variable name="param-pseudo-name" select="substring-after(local-name(), 'StylesheetParameter_name_')"/>
            <xsl:variable name="value-name" select="concat('StylesheetParameter_value_', $param-pseudo-name)"/>
            <xsl:value-of select="concat ('  parameter ', dpfunc:quoesc(.),
                                  ' ', dpfunc:quoesc(../*[local-name() = $value-name]), $eol)"/>
        </xsl:if>
    </xsl:template>

    <!-- default local-address + local-port properties -->
    <xsl:template mode="ProxyService" match="LocalAddress">
        <xsl:value-of select="concat('  local-address ', text(), ' ', ../LocalPort, $eol)"/>
    </xsl:template>
    
    <!-- type 'static-backend' requires valid remoteAddr and remotePort -->
    <xsl:template mode="ProxyService" match="Type[text()='static-backend']">
        <xsl:value-of select="concat('  remote-address ', ../RemoteAddress, ' ', ../RemotePort, $eol)"/>
    </xsl:template>

    <!-- type 'loopback-proxy' is expressed with '%loopback%' as CLI remoteAddr -->                
    <xsl:template mode="ProxyService" match="Type[text()='loopback-proxy']">
        <xsl:value-of select="concat('  remote-address %loopback%', $eol)"/>
    </xsl:template>

    <!-- type 'dynamic-backend' is expressed with '%dynamic%' as CLI remoteAddr -->
    <xsl:template mode="ProxyService" match="Type[text()='dynamic-backend']">
        <xsl:value-of select="concat('  remote-address %dynamic%', $eol)"/>
    </xsl:template>

    <!-- type 'strict-proxy' is expressed with '%proxy%' as CLI remoteAddr -->
    <xsl:template mode="ProxyService" match="Type[text()='strict-proxy']">
        <xsl:value-of select="concat('  remote-address %proxy%', $eol)"/>
    </xsl:template>

    <xsl:template mode="ProxyService" match="ACL">
      <xsl:if test="string(.)">
        <xsl:value-of select="concat('  acl ', ., $eol)"/>
      </xsl:if>
    </xsl:template>

    <!-- default stylesheet parameter properties -->
    <xsl:template mode="ProxyService" match="StylesheetParameters">
        <xsl:value-of select="concat('  parameter ', dpfunc:quoesc(ParameterName), ' ', dpfunc:quoesc(ParameterValue), $eol)"/>
    </xsl:template>

    <!-- remaining XSLProxyService menu properties -->
    <xsl:template mode="XSLProxyService" match="XMLManager
                                                |StylePolicy
                                                |URLRewritePolicy
                                                |SSLProxy
                                                |CountMonitors
                                                |DurationMonitors
                                                |MonitorProcessingPolicy
                                                |DefaultParamNamespace
                                                |UserSummary
                                                |DebugMode
                                                |DebugHistory
                                                |DebuggerType
                                                |DebuggerURL
                                                |DebugTrigger
                                                |mAdminState
                                                |Priority">
        <xsl:apply-templates mode="DefaultProperty" select=".">
            <xsl:with-param name="objName" select="name(..)"/>
            <xsl:with-param name="pName" select="name()"/>
            <xsl:with-param name="pValue" select="."/>
            <xsl:with-param name="Indent" select="'  '"/>
        </xsl:apply-templates>
    </xsl:template>

    <!-- bug 9011: empty string is valid -->
    <xsl:template mode="XSLProxyService" match="QueryParamNamespace">
        <xsl:value-of select="concat('  query-param-namespace ',
                              dpfunc:quoesc(.), $eol)"/>
    </xsl:template>

    <xsl:template mode="XSLProxyService" match="*"/>
    
  <!-- ************************************************************ -->
  <!-- StylePolicyRule mode -->
  <!-- ************************************************************ -->
  
    <!-- suppress local rule objects, since they will be expressed otherwise,
         through the canonical object template -->
    <xsl:template mode="cli-object" match="StylePolicyRule[@local='true']"/>
    
    <xsl:template mode="cli-object" match="StylePolicyRule[not(@local='true')]">
        <xsl:value-of select="concat($eol, 'rule ', dpfunc:quoesc(@name), $eol)"/>
        <xsl:if test="($delta-config=true())">
            <xsl:value-of select="concat('  reset', $eol)"/>
        </xsl:if>
        <xsl:apply-templates mode="StylePolicyRule">
            <xsl:with-param name="configuration" select=".."/>
        </xsl:apply-templates>
        <xsl:value-of select="concat('exit', $eol )"/>
    </xsl:template>

    <xsl:template mode="StylePolicyRule" match="Actions">
        <xsl:param name="configuration"/>

        <!-- 
             This is a reference property: we need to find the referenced object
             and inline it if (a) it is marked as local and (b) all it's properties
             can be expressed in the legacy one-line syntax.           
             
             To find the referenced action, look in two places: (1) new configuration 
             being submitted right now (2) existing config on box
             -->
        <xsl:variable name="actionName" select="."/>

        <!-- Find the referenced action. It may be in the incoming config or in the -->
        <!-- existing config -->
        <xsl:variable name="theAction">
            <xsl:choose>
                <xsl:when test="count($configuration/StylePolicyAction[@name=$actionName])">
                    <xsl:copy-of select="$configuration/StylePolicyAction[@name=$actionName]"/>
                </xsl:when>
                <xsl:when test="($delta-config)">
                    <xsl:copy-of select="$cli-existing//configuration/StylePolicyAction[@name=$actionName]"/>
                </xsl:when>
            </xsl:choose>
        </xsl:variable>

        <!-- use a template to decide if the action can and should be expressed -->
        <!-- as a one-liner -->
        <xsl:variable name="IsLocal">
            <xsl:call-template name="IsActionLocal">
                <xsl:with-param name="action" select="$theAction/*"/>
            </xsl:call-template>
        </xsl:variable>

        <xsl:text>  </xsl:text>
        <xsl:choose>
            <xsl:when test="$IsLocal/local">
                <xsl:apply-templates mode="LocalStylePolicyAction" select="$theAction/*"/>
            </xsl:when>                
            <xsl:otherwise>
                <!-- If the action's not local, you may not have access to it in Import.
                     But it turns out that all we need in that case is the name, which
                     we have. -->
                <xsl:value-of select="concat('  ', 'action', ' ', $actionName, $eol)"/>
            </xsl:otherwise>
        </xsl:choose>        

    </xsl:template>

  <!-- ************************************************************ -->
  <!-- StylePolicyAction mode -->
  <!-- ************************************************************ -->

    <!-- this template is applicable to both local and non-local actions,
         hence no suppression is needed -->
    <xsl:template mode="cli-object" match="StylePolicyAction">

        <xsl:variable name="IsLocal">
            <xsl:call-template name="IsActionLocal">
                <xsl:with-param name="action" select="."/>
            </xsl:call-template>
        </xsl:variable>

        <!-- only if it isn't local -->
        <xsl:if test="not($IsLocal/local)">
            <xsl:value-of select="concat($eol, 'action ', @name, $eol)"/>
            <xsl:if test="($delta-config=true())">
                <xsl:value-of select="concat('  reset', $eol)"/>
            </xsl:if>
            <xsl:apply-templates mode="StylePolicyAction" select="*"/>           
            <xsl:value-of select="concat('exit', $eol)"/>
        </xsl:if>

    </xsl:template>

    <!-- suppress log level for all non-log actions -->
    <xsl:template mode="StylePolicyAction" match="LogLevel[not(../Type='log')]"/>

    <!-- supress checkpoint event for all non-checkpoint actions -->
    <xsl:template mode="StylePolicyAction" match="CheckpointEvent[not(../Type='checkpoint')]"/>

    <!-- supress error-mode for all non-on-error actions -->
    <xsl:template mode="StylePolicyAction" match="ErrorMode[not(../Type='on-error')]"/>

    <!-- wish list: CanonicalProperty handles complex props (rtb: done.) -->
    <xsl:template mode="StylePolicyAction" match="StylesheetParameters">
        <xsl:value-of select="concat('  parameter ', dpfunc:quoesc(ParameterName), ' ', dpfunc:quoesc(ParameterValue), $eol)"/>
    </xsl:template>

    <xsl:template mode="StylePolicyAction" match="Type">
        <xsl:variable name="objName" select="name(..)"/>
        <xsl:variable name="pName" select="name()"/>
        <xsl:variable name="pNode" 
            select="$config-objects-index/self::object[@name=$objName]/ancestor-or-self::*/properties/property[@name=$pName]"/>

        <xsl:value-of select="concat('  ', $pNode/cli-alias, ' ', ., $eol )"/>
    </xsl:template>

    <xsl:template mode="StylePolicyAction" match="*">
        <xsl:apply-templates mode="CanonicalProperty" select="."/>
    </xsl:template>

    <xsl:template name="IsActionLocal">
        <xsl:param name="action"/>
        <xsl:choose>
          <xsl:when test="($action/@local='true') 
                          and (count($action/StylesheetParameters)=0) 
                          and ($action/OutputType = 'default')">
            <local/>
          </xsl:when>
          <xsl:otherwise></xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <xsl:template mode="LocalStylePolicyAction" match="StylePolicyAction">
      <xsl:choose>
            <xsl:when test="(Type='xform' or Type='xformpi' or Type='xformbin')">
                <xsl:choose>
                    <xsl:when test="(DynamicStylesheet!='')">
                        <xsl:value-of select="concat('  ', Type, ' ', dpfunc:quoesc(Input), 
                                              ' dynamic-stylesheet ', dpfunc:quoesc(DynamicStylesheet),
                                              ' ', dpfunc:quoesc(Output), $eol )"/>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:value-of select="concat('  ', Type, ' ', dpfunc:quoesc(Input), 
                                                     ' ', dpfunc:quoesc(Transform), 
                                                     ' ', dpfunc:quoesc(Output))"/>                                                     
                        <xsl:if test="(Policy!='')">
                            <xsl:value-of select="concat(' ', dpfunc:quoesc(Policy))"/>
                        </xsl:if>
                        <xsl:value-of select="concat($eol)"/>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:when>            
            <xsl:when test="(Type='validate')">
                <xsl:choose>
                    <xsl:when test="(DynamicSchema!='')">
                        <xsl:value-of select="concat('  ', Type, ' ', dpfunc:quoesc(Input), 
                                                     ' dynamic-schema ', DynamicSchema)"/>
                    </xsl:when>
                    <xsl:when test="(SchemaURL!='') and (Policy!='')">
                        <xsl:value-of select="concat('  ', Type, ' ', dpfunc:quoesc(Input),
                                                     ' schema-rewrite ',
                                                     dpfunc:quoesc(SchemaURL),
                                                     ' ', dpfunc:quoesc(Policy))"/>
                    </xsl:when>
                    <xsl:when test="(SchemaURL!='')">
                        <xsl:value-of select="concat('  ', Type, ' ', dpfunc:quoesc(Input), 
                                                     ' schema ', dpfunc:quoesc(SchemaURL))"/>
                    </xsl:when>
                    <xsl:when test="(Policy!='')">
                        <xsl:value-of select="concat('  ', Type, ' ', dpfunc:quoesc(Input), 
                                                     ' attribute-rewrite ', dpfunc:quoesc(Policy))"/>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:value-of select="concat('  ', Type, ' ', dpfunc:quoesc(Input))"/>
                    </xsl:otherwise>
                </xsl:choose>
				<xsl:if test="(Output!='')">
				  <xsl:value-of select="concat(' ', dpfunc:quoesc(Output))"/>
				</xsl:if>              
                <xsl:value-of select="concat($eol)"/>
            </xsl:when>

            <xsl:when test="Type='filter' or Type='route-action'">
                <xsl:choose>
                    <xsl:when test="(DynamicStylesheet!='')">
                        <xsl:value-of select="concat('  ', Type, ' ', dpfunc:quoesc(Input),
                                              ' dynamic-stylesheet ', dpfunc:quoesc(DynamicStylesheet) )"/>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:value-of select="concat('  ', Type, ' ', dpfunc:quoesc(Input), 
                                              ' ', dpfunc:quoesc(Transform) )"/>
                    </xsl:otherwise>
                </xsl:choose>
	        <xsl:if test="(Output!='')">
                    <xsl:value-of select="concat(' ', dpfunc:quoesc(Output) )"/>
		</xsl:if>              
                <xsl:value-of select="concat($eol)"/>
            </xsl:when>

            <xsl:when test="(Type='convert-http')">
                 <xsl:value-of select="concat('  ', Type, ' ', dpfunc:quoesc(Input), 
                                              ' ', dpfunc:quoesc(Output), 
                                              ' ', InputConversion, $eol)"/>
            </xsl:when>

            <xsl:when test="(Type='rewrite')">
                 <xsl:value-of select="concat('  ', Type, ' ', dpfunc:quoesc(Policy), $eol)"/>
            </xsl:when>

            <xsl:when test="(Type='fetch')">
                 <xsl:value-of select="concat('  ', Type, ' ', dpfunc:quoesc(Destination),
							   ' ', dpfunc:quoesc(Output), $eol)"/>
            </xsl:when>

            <xsl:when test="(Type='extract')">
                 <xsl:value-of select="concat('  ', Type, 
				 ' ', dpfunc:quoesc(Input),
				 ' ', dpfunc:quoesc(Output),
				 ' ', dpfunc:quoesc(XPath) )"/>

				 <xsl:if test="(Variable!='')">
                   <xsl:value-of select="concat(' ', dpfunc:quoesc(Variable))"/>
				 </xsl:if>
                 <xsl:value-of select="concat($eol)"/>
            </xsl:when>

            <xsl:when test="(Type='route-set')">
                 <xsl:value-of select="concat('  ', Type, 
				 ' ', dpfunc:quoesc(Destination))"/>
				 <xsl:if test="(SSLCred!='')">
				    <xsl:value-of select="concat(' ', dpfunc:quoesc(SSLCred))"/>
				 </xsl:if>
                 <xsl:value-of select="concat($eol)"/>
            </xsl:when>
			
            <xsl:when test="(Type='strip-attachments')">
                 <xsl:value-of select="concat('  ', Type, 
				 ' ', dpfunc:quoesc(Input))"/>
				 <xsl:if test="(AttachmentURI!='')">
				    <xsl:value-of select="concat(' ', dpfunc:quoesc(AttachmentURI))"/>
				 </xsl:if>
                 <xsl:value-of select="concat($eol)"/>              
            </xsl:when>

            <xsl:when test="(Type='setvar')">
                 <xsl:value-of select="concat('  ', Type, 
                                       ' ', Input, ' ', Variable, 
                                       ' ', dpfunc:quoesc(Value), $eol)"/>
            </xsl:when>

            <xsl:when test="(Type='results' or Type='log')">
                <xsl:value-of select="concat('  ', Type, ' ', dpfunc:quoesc(Input))"/>
    		<xsl:if test="(Destination!='')">
                    <xsl:value-of select="concat(' ', dpfunc:quoesc(Destination))"/>
                    <xsl:if test="(Output!='')">
                        <xsl:value-of select="concat(' ', dpfunc:quoesc(Output))"/>
                    </xsl:if>
                </xsl:if>
                <xsl:value-of select="concat($eol)"/>
            </xsl:when>

            <xsl:when test="(Type='results-async')">
              <xsl:value-of select="concat('  ', Type, ' ', dpfunc:quoesc(Input))"/>
              <xsl:value-of select="concat(' ', dpfunc:quoesc(Destination))"/>
              <xsl:value-of select="$eol"/>
             </xsl:when>
             
             <xsl:when test="(Type='aaa')">
               <xsl:value-of select="concat( '  ', Type, ' ', dpfunc:quoesc(Input), ' ', dpfunc:quoesc(AAA), ' ', dpfunc:quoesc(Output), $eol )"/>
             </xsl:when>

             <xsl:when test="(Type='slm')">
               <xsl:value-of select="concat( '  ', Type, ' ', dpfunc:quoesc(Input), ' ', dpfunc:quoesc(SLMPolicy), ' ', dpfunc:quoesc(Output), $eol )"/>
             </xsl:when>

             <xsl:when test="(Type='sql')">
                <xsl:value-of select="concat( ' ', Type, ' ', dpfunc:quoesc(Input), ' ', dpfunc:quoesc(SQLDataSource), ' ', dpfunc:quoesc(SQLSourceType), ' ', dpfunc:quoesc(SQLText), ' ', $eol )"/>
             </xsl:when>

             <xsl:when test="(Type='call')">
               <xsl:value-of select="concat( '  ', Type, ' ', dpfunc:quoesc(Input), ' ', dpfunc:quoesc(Transform), ' ', dpfunc:quoesc(Output), $eol )"/>
             </xsl:when>

             <xsl:when test="(Type='checkpoint')">
               <xsl:value-of select="concat( '  ', Type, ' ', CheckpointEvent, $eol )"/>
             </xsl:when>

             <xsl:when test="(Type='on-error')">
               <xsl:value-of select="concat( '  ', Type, ' ', ErrorMode)"/>
               <xsl:if test="Rule!=''">
                 <xsl:value-of select="concat(' ', dpfunc:quoesc(Rule))"/>                 
               </xsl:if>
               <xsl:if test="ErrorInput!=''">
                 <xsl:value-of select="concat(' ', dpfunc:quoesc(ErrorInput))"/>                 
               </xsl:if>
               <xsl:if test="ErrorOutput!=''">
                 <xsl:value-of select="concat(' ', dpfunc:quoesc(ErrorOutput))"/>                 
               </xsl:if>               
               <xsl:value-of select="$eol"/>
             </xsl:when>

             <xsl:otherwise>
               <xsl:value-of select="concat('unrecognized type ', Type)"/>
             </xsl:otherwise>

        </xsl:choose>
    </xsl:template>

    <xsl:template mode="StylePolicyRule" match="*">
        <xsl:apply-templates mode="CanonicalProperty" select="."/>
    </xsl:template>

    <!-- ************************************************************ -->
    <!-- Matching -->
    <!-- ************************************************************ -->
    
    <xsl:template mode="cli-delete-object" match="Matching">
        <xsl:value-of select="concat('no matching ', @name, $eol)"/>
    </xsl:template>

    <xsl:template mode="cli-object" match="Matching">
        <xsl:value-of select="concat($eol, 'matching ', dpfunc:quoesc(@name), $eol)"/>
        <xsl:if test="($delta-config=true())">
            <xsl:value-of select="concat('  reset', $eol)"/>
        </xsl:if>
        <xsl:apply-templates mode="Matching"/>
        <xsl:value-of select="concat('exit', $eol )"/>
    </xsl:template>

    <xsl:template mode="Matching" match="MatchRules[Type='url']">
        <xsl:value-of select="concat('  urlmatch ', dpfunc:quoesc(Url), $eol)"/>
    </xsl:template>

    <xsl:template mode="Matching" match="MatchRules[Type='errorcode']">
      <xsl:value-of select="concat(' errorcode ', dpfunc:quoesc(ErrorCode), $eol)"/>
    </xsl:template>

    <xsl:template mode="Matching" match="MatchRules[Type='http']">
        <xsl:value-of select="concat('  httpmatch ', dpfunc:quoesc(HttpTag), 
                                     ' ', dpfunc:quoesc(HttpValue), $eol)"/>
    </xsl:template>

    <xsl:template mode="Matching" match="MatchRules[Type='xpath']">
      <xsl:value-of select="concat(' xpathmatch ', dpfunc:quoesc(XPATHExpression), $eol)"/>
    </xsl:template>

    <xsl:template mode="Matching" match="MatchRules[Type='fullyqualifiedurl']">
        <xsl:value-of select="concat('  fullurlmatch ', dpfunc:quoesc(Url), $eol)"/>
    </xsl:template>

    <xsl:template mode="Matching" match="MatchRules[Type='host']">
        <xsl:value-of select="concat('  hostmatch ', dpfunc:quoesc(Url), $eol)"/>
    </xsl:template>

    <xsl:template mode="Matching" match="UserSummary|mAdminState|MatchWithPCRE|CombineWithOr">
        <xsl:apply-templates mode="CanonicalProperty" select="."/>
    </xsl:template>

    <xsl:template mode="Matching" match="*"/>


    <!-- ************************************************************ -->
    <!-- ImportPackage -->
    <!-- ************************************************************ -->
    
    <xsl:template mode="cli-object" match="ImportPackage">
        <xsl:apply-templates mode="CanonicalObject" select="."/>
        <!-- if creating config file and admin state is enabled -->
        <!-- add 'import-execute objname' directive             -->
        <xsl:if test="(($delta-config=false()) and (mAdminState='enabled') and (OnStartup='on'))">
            <xsl:value-of select="concat($eol,'import-execute ', dpfunc:quoesc(@name),$eol)"/>
        </xsl:if>
    </xsl:template>

    <!-- ************************************************************ -->
    <!-- IncludeConfig -->
    <!-- ************************************************************ -->
    
    <xsl:template mode="cli-object" match="IncludeConfig">
        <xsl:apply-templates mode="CanonicalObject" select="."/>
        <!-- if creating config file and admin state is enabled -->
        <xsl:if test="(($delta-config=false()) and (mAdminState='enabled') and (OnStartup='on'))">
            <xsl:choose>
                <xsl:when test="InterfaceDetection='on'">
                    <!-- add 'exec objname' directive -->
                    <xsl:value-of select="concat($eol,'exec ', dpfunc:quoesc(@name),$eol)"/>
                </xsl:when>
                <xsl:otherwise>
                    <!-- add 'exec url' directive -->
                    <xsl:value-of select="concat($eol,'exec ', dpfunc:quoesc(URL),$eol)"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:if>
    </xsl:template>

    <!-- ************************************************************ -->
    <!-- ShellAlias -->
    <!-- ************************************************************ -->
    
    <xsl:template mode="cli-object" match="ShellAlias">
        <xsl:value-of select="concat($eol, 'alias ', dpfunc:quoesc(@name), 
                                     ' ', dpfunc:quoesc(normalize-space(command)), $eol)"/>
    </xsl:template>

    <!-- XSLCoprocService -->
    <xsl:template mode="cli-object" match="XSLCoprocService">
        <xsl:call-template name="available-open">
            <xsl:with-param name="name" select="local-name()"/>
        </xsl:call-template>

        <xsl:value-of select="concat($eol, 'xslcoproc ', dpfunc:quoesc(@name), $eol)"/>
        <xsl:if test="($delta-config=true())">
            <xsl:value-of select="concat('  reset', $eol)"/>
        </xsl:if>
        <xsl:apply-templates mode="XSLCoprocService"/>
        <xsl:value-of select="concat('exit', $eol )"/>
        <xsl:call-template name="available-close">
            <xsl:with-param name="name" select="local-name()"/>
        </xsl:call-template>

    </xsl:template>

    <!-- local-address + local-port properties -->
    <xsl:template mode="XSLCoprocService" match="LocalAddress">
        <xsl:value-of select="concat('  local-address ', text(), ' ', ../LocalPort, $eol)"/>
    </xsl:template>
    
    <xsl:template mode="XSLCoprocService" match="LocalPort"/>
    
    <!-- default-param-namespace -->
    <xsl:template mode="XSLCoprocService" match="DefaultParamNamespace">
        <xsl:value-of select="concat('  default-param-namespace ', dpfunc:quoesc(text()), $eol)"/>
    </xsl:template>
    
    <!-- remaining XSLCoprocService menu properties -->
    <xsl:template mode="XSLCoprocService" match="*">
        <xsl:apply-templates mode="DefaultProperty" select=".">
            <xsl:with-param name="objName" select="name(..)"/>
            <xsl:with-param name="pName" select="name()"/>
            <xsl:with-param name="pValue" select="."/>
            <xsl:with-param name="Indent" select="'  '"/>
        </xsl:apply-templates>
    </xsl:template>
                                                                                      
    <!-- ************************************************************ -->
    <!-- URLRewritePolicy -->
    <!-- ************************************************************ -->
    
    <xsl:template mode="cli-object" match="URLRewritePolicy">
        <xsl:value-of select="concat($eol, 'urlrewrite ', dpfunc:quoesc(@name), $eol)"/>
        <xsl:if test="($delta-config=true())">
            <xsl:value-of select="concat('  reset', $eol)"/>
        </xsl:if>
        <xsl:apply-templates mode="URLRewritePolicy"/>
        <xsl:value-of select="concat('exit', $eol)"/>
    </xsl:template>


    <xsl:template mode="URLRewritePolicy" match="URLRewriteRule">
        <xsl:variable name="input-replace">
            <xsl:apply-templates select="InputReplaceRegexp" mode="NullableValue"/>
        </xsl:variable>
        <xsl:variable name="style-replace">
            <xsl:apply-templates select="StyleReplaceRegexp" mode="NullableValue"/>
        </xsl:variable>
        <xsl:choose>
            <xsl:when test="Type='content-type'">
                <xsl:value-of select="concat('  ', Type, ' ', dpfunc:quoesc(MatchRegexp),
                                             ' ', $input-replace, ' ', NormalizeURL, $eol )"/>
            </xsl:when>
            <xsl:when test="Type='post-body'">
                <xsl:value-of select="concat('  ', Type, ' ', $quote, $quote, ' ', dpfunc:quoesc(MatchRegexp),
                                             ' ', $input-replace, ' ', $style-replace,
                                             ' ', InputUnescape, ' ', StylesheetUnescape, ' ', NormalizeURL, $eol )"/>
            </xsl:when>
            <xsl:when test="Type='header-rewrite'">
                <xsl:value-of select="concat('  ', Type, ' ', Header, ' ', dpfunc:quoesc(MatchRegexp),
                                             ' ', $input-replace, ' ', NormalizeURL, $eol )"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="concat('  ', Type, ' ', dpfunc:quoesc(MatchRegexp),
                                             ' ', $input-replace, ' ', $style-replace,
                                             ' ', InputUnescape, ' ', StylesheetUnescape, ' ', NormalizeURL, $eol )"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <xsl:template mode="URLRewritePolicy" match="mAdminState">
      <xsl:apply-templates mode="CanonicalProperty" select="."/>
    </xsl:template>

    <xsl:template mode="URLRewritePolicy" match="Direction">
      <xsl:apply-templates mode="CanonicalProperty" select="."/>
    </xsl:template>

    <xsl:template mode="URLRewritePolicy" match="*"/>

    <!-- ************************************************************ -->
    <!-- SSLProxyProfile -->
    <!-- ************************************************************ -->
    
    <xsl:template mode="cli-object" match="SSLProxyProfile">
        <xsl:value-of select="concat($eol, 'sslproxy ', dpfunc:quoesc(@name), ' ', Direction)"/>

        <xsl:if test="Direction = 'reverse' or Direction = 'two-way'">
            <xsl:value-of select="concat(' ', dpfunc:quoesc(ReverseCryptoProfile))"/>
        </xsl:if>
        <xsl:if test="Direction = 'forward' or Direction = 'two-way'">
            <xsl:value-of select="concat(' ', dpfunc:quoesc(ForwardCryptoProfile))"/>
        </xsl:if>

        <xsl:apply-templates mode="SSLProxyProfile"/>
        <xsl:value-of select="concat($eol)"/>
    </xsl:template>

    <!-- These are handled in main template for SSLProxyProfile -->
    <xsl:template mode="SSLProxyProfile" match="ForwardCryptoProfile"/>
    <xsl:template mode="SSLProxyProfile" match="ReverseCryptoProfile"/>
    <xsl:template mode="SSLProxyProfile" match="Direction"/>

    <xsl:template mode="SSLProxyProfile" match="ServerCaching">
        <xsl:if test="../Direction = 'reverse' or ../Direction = 'two-way'">
            <xsl:choose>
                <!-- ServerCaching is just a flag indicating that server
                     caching is on or off, if off then sess-timeout must
                     be 0 -->
                <xsl:when test=". = 'off'">
                    <xsl:value-of select="concat(' sess-timeout 0')"/>
                </xsl:when>

                <xsl:otherwise>
                    <xsl:value-of select="concat(' sess-timeout ', ../SessionTimeout, ' cache-size ', ../CacheSize)"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:if>
    </xsl:template>

    <xsl:template mode="SSLProxyProfile" match="mAdminState">
      <xsl:if test="../mAdminState='disabled'">
        <xsl:value-of select="concat(' admin-state ',dpfunc:quoesc(.))"/>
      </xsl:if>
    </xsl:template>

    <!-- Eat SessionTimeout and CacheSize because they're handled in the
         template for ServerCaching -->
    <xsl:template mode="SSLProxyProfile" match="SessionTimeout|CacheSize"/>

    <xsl:template mode="SSLProxyProfile" match="ClientCache">
        <xsl:if test="../Direction = 'forward' or ../Direction = 'two-way'">
            <xsl:value-of select="concat(' client-cache ', text())"/>
        </xsl:if>
    </xsl:template>

    <!--
         These parameters were added to this command *much* later than the rest
         of the parameters, so it is very important not to serialize them at all
         unless they have the non-default value (so as to be downgrade
         compatible if at all possible).
      -->
    <xsl:template mode="SSLProxyProfile"
                  match="ClientAuthOptional|ClientAuthAlwaysRequest">
        <xsl:if test="(../Direction = 'reverse' or ../Direction = 'two-way') and text() = 'on'">
            <!--
                 This should really just use cli-alias (instead of xsl:choose),
                 but it isn't clear how to do so.
            -->
            <xsl:choose>
                <xsl:when test="self::ClientAuthOptional">
                    <xsl:value-of select="' client-auth-optional on'"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="' client-auth-always-request on'"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:if>
    </xsl:template>

    <!-- ************************************************************ -->
    <!-- XMLFirewallService -->
    <!-- ************************************************************ -->
  
    <xsl:template mode="cli-object" match="XMLFirewallService">
        <xsl:call-template name="available-open">
            <xsl:with-param name="name" select="local-name()"/>
        </xsl:call-template>

        <xsl:variable name="importFromWebsphere" select="/request/args/importedFromWebsphere"/>
        <xsl:choose>
            <xsl:when test="$importFromWebsphere='true'">
                <xsl:call-template name="XMLFirewallServiceWebsphere">
                    <xsl:with-param name="args" select="."/>
                </xsl:call-template>
            </xsl:when>
        </xsl:choose>

        <!-- XML Firewall menu properties -->
        <xsl:value-of select="concat($eol, 'xmlfirewall ', dpfunc:quoesc(@name), $eol)"/>
        <xsl:if test="($delta-config=true())">
            <xsl:value-of select="concat('  reset', $eol)"/>
        </xsl:if>
        <xsl:apply-templates mode="XMLFirewallService"/>
        <xsl:value-of select="concat('exit', $eol )"/>
        <!-- HTTP proxy menu properties -->
        <xsl:call-template name="HTTPProxyServiceProperties">
            <xsl:with-param name="identifier" select="'xmlfirewall'"/>
        </xsl:call-template>
        <xsl:call-template name="available-close">
            <xsl:with-param name="name" select="local-name()"/>
        </xsl:call-template>
    </xsl:template>
    
    <!-- bug 9011: empty string is valid -->
    <xsl:template mode="XMLFirewallService" match="QueryParamNamespace">
        <xsl:value-of select="concat('  query-param-namespace ',
                              dpfunc:quoesc(.), $eol)"/>
    </xsl:template>

    <!-- remaining XMLFirewallService menu properties -->
    <xsl:template mode="XMLFirewallService" match="XMLManager
                                                    |StylePolicy
                                                    |URLRewritePolicy
                                                    |SSLProxy
                                                    |MaxMessageSize
                                                    |RequestType
                                                    |ResponseType
                                                    |FWCred
                                                    |CountMonitors
                                                    |DurationMonitors
                                                    |ServiceMonitors
                                                    |MonitorProcessingPolicy
                                                    |DefaultParamNamespace
                                                    |RequestAttachments
                                                    |ResponseAttachments
                                                    |RootPartNotFirstAction
                                                    |MIMEHeaders
                                                    |mAdminState
                                                    |UserSummary
                                                    |SOAPSchemaURL
                                                    |DebugMode
                                                    |DebugHistory
                                                    |DebuggerType
                                                    |DebuggerURL
                                                    |DebugTrigger
                                                    |FirewallParserLimits
                                                    |WSDLResponsePolicy
                                                    |WSDLFileLocation
                                                    |ParserLimitsBytesScanned
                                                    |ParserLimitsElementDepth
                                                    |ParserLimitsAttributeCount
                                                    |ParserLimitsMaxNodeSize
                                                    |ParserLimitsExternalReferences
                                                    |ParserLimitsForbidExternalReferences
                                                    |ParserLimitsAttachmentByteCount
                                                    |ParserLimitsAttachmentPackageByteCount
                                                    |FrontAttachmentFormat
                                                    |BackAttachmentFormat
                                                    |Priority">
        <xsl:apply-templates mode="DefaultProperty" select=".">
            <xsl:with-param name="objName" select="name(..)"/>
            <xsl:with-param name="pName" select="name()"/>
            <xsl:with-param name="pValue" select="."/>
            <xsl:with-param name="Indent" select="'  '"/>
        </xsl:apply-templates>
    </xsl:template>
    
    <xsl:template mode="XMLFirewallService" match="*"/>

    <!-- ***************************************************** -->
    <!--  AAAPolicy                                       -->
    <!-- ***************************************************** -->

    <xsl:template mode="cli-object" match="AAAPolicy">
        <xsl:call-template name="available-open">
            <xsl:with-param name="name" select="local-name()"/>
        </xsl:call-template>
      <xsl:value-of select="concat($eol, 'aaapolicy ', dpfunc:quoesc(@name), $eol)"/>
      <xsl:if test="($delta-config=true())">
          <xsl:value-of select="concat('  reset', $eol)"/>
      </xsl:if>

      <xsl:apply-templates mode="AAAPolicy"/>
      <xsl:value-of select="concat('exit', $eol)"/>
        <xsl:call-template name="available-close">
            <xsl:with-param name="name" select="local-name()"/>
        </xsl:call-template>
    </xsl:template>

    <xsl:template mode="AAAPolicy" match="Authenticate|Authorize|MapCredentials|MapResource|ExtractIdentity|PostProcess|ExtractResource">
        <xsl:variable name="current" select="." />
        <xsl:variable name="schema-prop-node" select="$config-objects-index/self::object[@name = 'AAAPolicy']/properties/property[@name = local-name($current)]" />

        <!-- cli command from drMgmt -->
        <xsl:value-of select='concat(" ",normalize-space($schema-prop-node/cli-alias)," ")'/>


        <!-- these four groups, the second command arg represents one of two properties -->
        <xsl:if test="boolean(
                               local-name() = 'Authenticate' or
                               local-name() = 'Authorize' or
                               local-name() = 'MapCredentials' or
                               local-name() = 'MapResource'
                             )">
            <xsl:variable name="method" select="AUMethod|MCMethod|MRMethod|AZMethod" />

            <!-- include the first argument for this set is "method" -->
            <xsl:value-of select='concat($method, " ")' />

            <!-- the second argument for this set is the custom url, map url, xpath expression, or "" -->
      <xsl:choose>
        <xsl:when test="$method = 'custom'">
                    <xsl:value-of select="dpfunc:quoesc( AUCustomURL|MCCustomURL|MRCustomURL|AZCustomURL )" />
        </xsl:when>
        <xsl:when test="$method = 'xmlfile'">
                    <xsl:value-of select="dpfunc:quoesc( AUMapURL|MCMapURL|MRMapURL|AZMapURL )" />
        </xsl:when>
        <xsl:when test="$method = 'xpath'">
                    <xsl:value-of select="dpfunc:quoesc( MCMapXPath|MRMapXPath )" />
        </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="dpfunc:quoesc('')" />
                </xsl:otherwise>
      </xsl:choose>
        </xsl:if>

        <!-- arguments are supplied in the same order as listed in drMgmt.
             For AU, MC, MR, and AZ, skip the method and url properties since they are set above
          -->
        <xsl:for-each select="$type-index/self::type[@name = $schema-prop-node/@type]/properties/property[
                              not( regexp:test( @name, '^(AU|MC|MR|AZ)(Method|CustomURL|MapURL)$' ) ) ]">
            <xsl:variable name="arg-node" select="$current/*[local-name() = current()/@name]" />

          <xsl:choose>
                <xsl:when test="string($type-index/self::type[@name = current()/@type]/@base) = 'bitmap'">
                    <xsl:value-of select='concat(" ", dpfunc:quoesc(dpfunc:bitmap-to-string($arg-node)))' />
            </xsl:when>
            <xsl:otherwise>
                    <xsl:value-of select='concat(" ", dpfunc:quoesc($arg-node))'/>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:for-each>

      <xsl:value-of select="$eol"/>
    </xsl:template>

    <!-- this -1 priority template will match everything else not specified by other AAAPolicy templates. -->
    <xsl:template mode="AAAPolicy" match="*" priority="-1">
        <xsl:apply-templates mode="CanonicalProperty" select="."/>
    </xsl:template>

    <xsl:template mode="AAAPolicy" match="NamespaceMapping">
      <xsl:value-of select="concat('  namespace-mapping ', dpfunc:quoesc(Prefix), ' ', dpfunc:quoesc(URI), $eol)"/>
    </xsl:template>

    <xsl:template mode="AAAPolicy" match="SAMLAttribute">
      <xsl:value-of select="concat('  saml-attribute ', dpfunc:quoesc(URI),
                                   ' ', dpfunc:quoesc(LocalName),
                                   ' ', dpfunc:quoesc(Value), $eol)"/>
    </xsl:template>

    <xsl:template mode="AAAPolicy" match="LTPAAttributes">
        <xsl:value-of select="concat(' ltpa-attribute ', 
                              dpfunc:quoesc(LTPAUserAttributeName), ' ',
                              dpfunc:quoesc(LTPAUserAttributeType), ' ', 
                              dpfunc:quoesc(LTPAUserAttributeStaticValue), ' ',
                              dpfunc:quoesc(LTPAUserAttributeXPathValue), 
                              $eol)"/>
    </xsl:template>

    <xsl:template mode="AAAPolicy" match="TransactionPriority">
        <xsl:value-of select="concat(' transaction-priority ',
                              dpfunc:quoesc(Credential), ' ',
                              dpfunc:quoesc(Priority), ' ',
                              dpfunc:quoesc(Authorization), ' ',
                              $eol)"/>
    </xsl:template>

       
    <!-- ************************************************************ -->
    <!-- XMLFirewallServiceWebsphere -->
    <!-- ************************************************************ -->

    <xsl:template name="XMLFirewallServiceWebsphere">
        <xsl:param name="args"/>
    </xsl:template>

    <!-- ************************************************************ -->
    <!-- Crypto -->
    <!-- ************************************************************ -->
  
    <!-- Used by crypto templates to wrap "crypto" .. "exit" around crypto commands -->
    <xsl:template name="CryptoWrapper">
        <xsl:param name="cmdline"/>
        <xsl:if test="$cmdline != ''">
            <xsl:value-of select="concat($eol, 'crypto', $eol, '  ', $cmdline, $eol, 'exit', $eol)"/>
        </xsl:if>
    </xsl:template>

    <!-- CryptoKey -->
    <xsl:template mode="cli-delete-object" match="CryptoKey">
        <xsl:call-template name="CryptoWrapper">
            <xsl:with-param name="cmdline">
                <xsl:value-of select="concat('no key ', dpfunc:quoesc(@name), $eol)"/>
            </xsl:with-param>
        </xsl:call-template>
    </xsl:template>

    <xsl:template mode="cli-object" match="CryptoKey">
      <xsl:call-template name="CryptoWrapper">
        <xsl:with-param name="cmdline">
            <xsl:value-of select="concat('key ', dpfunc:quoesc(@name), ' ', dpfunc:quoesc(Filename))"/>
            
            <xsl:if test="(string(Password) != '')">
                <xsl:choose>
                    <xsl:when test="(PasswordAlias='on')">
                      <xsl:value-of select="concat(' password-alias ', dpfunc:quoesc(Password))"/>
                    </xsl:when>
                    <xsl:otherwise>
                      <xsl:value-of select="concat(' password ', dpfunc:quoesc(Password))"/>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:if>
            
            <xsl:if test="string(mAdminState) = 'disabled'">
                <xsl:value-of select="concat(' admin-state ', dpfunc:quoesc(mAdminState))"/>
            </xsl:if>
        </xsl:with-param>
      </xsl:call-template>
    </xsl:template>

    <!-- CryptoSSKey -->
    <xsl:template mode="cli-delete-object" match="CryptoSSKey">
        <xsl:call-template name="CryptoWrapper">
            <xsl:with-param name="cmdline">
                <xsl:value-of select="concat('no sskey ', dpfunc:quoesc(@name), $eol)"/>
            </xsl:with-param>
        </xsl:call-template>
    </xsl:template>

    <xsl:template mode="cli-object" match="CryptoSSKey">
        <xsl:call-template name="CryptoWrapper">
            <xsl:with-param name="cmdline">
                <xsl:value-of select="concat('sskey ', dpfunc:quoesc(@name), ' ', dpfunc:quoesc(Filename))"/>
                <xsl:if test="(string(Password) != '')">
                    <xsl:choose>
                        <xsl:when test="(PasswordAlias='on')">
                            <xsl:value-of select="concat(' password-alias ', dpfunc:quoesc(Password))"/>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:value-of select="concat(' password ', dpfunc:quoesc(Password))"/>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:if>
                <xsl:if test="(string(mAdminState) = 'disabled')">
                  <xsl:value-of select="concat(' admin-state ',dpfunc:quoesc(mAdminState))"/>
                </xsl:if>
            </xsl:with-param>
        </xsl:call-template>
    </xsl:template>

    <!-- CryptoCertificate -->
    <xsl:template mode="cli-delete-object" match="CryptoCertificate">
        <xsl:call-template name="CryptoWrapper">
            <xsl:with-param name="cmdline">
                <xsl:value-of select="concat('no certificate ', dpfunc:quoesc(@name), $eol)"/>
            </xsl:with-param>
        </xsl:call-template>
    </xsl:template>

    <xsl:template mode="cli-object" match="CryptoCertificate">
        <xsl:call-template name="CryptoWrapper">
            <xsl:with-param name="cmdline">
                <xsl:value-of select="concat('certificate ', dpfunc:quoesc(@name), ' ', dpfunc:quoesc(Filename))"/>
                <xsl:if test="(string(Password) != '')">
                    <xsl:choose>
                        <xsl:when test="(PasswordAlias='on')">
                            <xsl:value-of select="concat(' password-alias ', dpfunc:quoesc(Password))"/>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:value-of select="concat(' password ', dpfunc:quoesc(Password))"/>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:if>
                <xsl:if test="(string(mAdminState) = 'disabled')">
                  <xsl:value-of select="concat(' admin-state ',dpfunc:quoesc(mAdminState))"/>
                </xsl:if>
                <xsl:if test="string(IgnoreExpiration) = 'on'">
                  <xsl:value-of select="' ignore-expiration'"/>
                </xsl:if>
            </xsl:with-param>
        </xsl:call-template>
    </xsl:template>

    <!-- CryptoIdentCred -->
    <xsl:template mode="cli-delete-object" match="CryptoIdentCred">
        <xsl:call-template name="CryptoWrapper">
            <xsl:with-param name="cmdline">
                <xsl:value-of select="concat('no idcred ', dpfunc:quoesc(@name), $eol)"/>
            </xsl:with-param>
        </xsl:call-template>
    </xsl:template>

    <xsl:template mode="cli-object" match="CryptoIdentCred">
        <xsl:call-template name="CryptoWrapper">
            <xsl:with-param name="cmdline">
                <xsl:value-of select="concat('idcred ', dpfunc:quoesc(@name), 
                                             ' ', dpfunc:quoesc(Key), 
                                             ' ', dpfunc:quoesc(Certificate))"/>
                <xsl:if test="(CA) and not(string(CA)='')">
                    <xsl:apply-templates mode="CryptoIdentCred"/>
                </xsl:if>
                <xsl:if test="(string(mAdminState) = 'disabled')">
                  <xsl:value-of select="concat(' admin-state ',dpfunc:quoesc(mAdminState))"/>
                </xsl:if>
            </xsl:with-param>
        </xsl:call-template>
    </xsl:template>
    
    <xsl:template mode="CryptoIdentCred" match="CA">
        <xsl:value-of select="concat(' ca ', dpfunc:quoesc(text()))"/>
    </xsl:template>

    <!-- CryptoValCred -->
    <xsl:template mode="cli-delete-object" match="CryptoValCred">
        <xsl:call-template name="CryptoWrapper">
            <xsl:with-param name="cmdline">
                <xsl:value-of select="concat('no valcred ', dpfunc:quoesc(@name), $eol)"/>
            </xsl:with-param>
        </xsl:call-template>
    </xsl:template>

    <xsl:template mode="cli-object" match="CryptoValCred">
        <xsl:call-template name="CryptoWrapper">
            <xsl:with-param name="cmdline">
                <xsl:value-of select="concat('valcred ', dpfunc:quoesc(@name), $eol)"/>
                <xsl:if test="($delta-config=true())">
                    <xsl:value-of select="concat('  reset', $eol)"/>
                </xsl:if>
                <xsl:apply-templates mode="CryptoValCred"/>
                <xsl:value-of select="concat('  exit')"/>
            </xsl:with-param>
        </xsl:call-template>
    </xsl:template>

    <xsl:template mode="CryptoValCred" match="Certificate">
        <xsl:if test="text()">
            <xsl:value-of select="concat('    certificate ', dpfunc:quoesc(text()), $eol)"/>
        </xsl:if>
    </xsl:template>

    <xsl:template mode="CryptoValCred" match="mAdminState">
      <xsl:apply-templates mode="CanonicalProperty" select="."/>
    </xsl:template>

    <xsl:template mode="CryptoValCred" match="CertValidationMode">
        <xsl:value-of select="concat('    cert-validation-mode ', dpfunc:quoesc(text()), $eol)"/>
    </xsl:template>

    <xsl:template mode="CryptoValCred" match="UseCRL">
        <xsl:value-of select="concat('    use-crl ', dpfunc:quoesc(text()), $eol)"/>
    </xsl:template>

    <xsl:template mode="CryptoValCred" match="RequireCRL">
        <xsl:value-of select="concat('    require-crl ', dpfunc:quoesc(text()), $eol)"/>
    </xsl:template>

    <xsl:template mode="CryptoValCred" match="CRLDPHandling">
        <xsl:value-of select="concat('    crldp ', dpfunc:quoesc(text()), $eol)"/>
    </xsl:template>

    <xsl:template mode="CryptoValCred" match="InitialPolicySet">
        <xsl:value-of select="concat('    initial-policy-set ', dpfunc:quoesc(text()), $eol)"/>
    </xsl:template>

    <xsl:template mode="CryptoValCred" match="ExplicitPolicy">
        <xsl:value-of select="concat('    explicit-policy ', dpfunc:quoesc(text()), $eol)"/>
    </xsl:template>

    <xsl:template mode="CryptoValCred" match="InhibitAnyPolicy">
        <xsl:value-of select="concat('    inhibit-anypolicy ', dpfunc:quoesc(text()), $eol)"/>
    </xsl:template>

    <xsl:template name="CreateValidObjectName">
        <xsl:param name="input-name"/>
        <!-- translate characters which are illegal in named object names into
             something legal; note that ':' is deleted and not translated -->
        <xsl:value-of select="translate($input-name, '.,;#/\():', '--------')"/>
    </xsl:template>

    <!-- implement the 'ValCredAddCertsFromDir' action -->
    <xsl:template match="args[action='ValCredAddCertsFromDir']" mode="cli-actions">
        <!-- For now (7/03) force our directory always to pubcert:, we can
             generalize it by passing in Directory -->
        <xsl:variable name="dirname">
            <xsl:choose>
                <xsl:when test="Directory != ''">
                    <xsl:value-of select="Directory"/>
                </xsl:when>
                <xsl:otherwise>pubcert:</xsl:otherwise>
            </xsl:choose>
        </xsl:variable>

        <xsl:variable name="filelist">
            <xsl:call-template name="directory-filelist">
                <xsl:with-param name="directory-to-get" select="$dirname"/>
            </xsl:call-template>
        </xsl:variable>

        <!-- prelude to config -->
        <xsl:value-of select="concat('configure terminal', $eol, 'crypto', $eol)"/>

        <!-- create set of certificate object names -->
        <xsl:variable name="cert-objects">
          <xsl:for-each select="$filelist//file">
            <!-- Only include files which end in '.pem' -->
            <xsl:if test="substring(@name, string-length(@name) - string-length('.pem') + 1) = '.pem'">
              <cert-object>
                <name>
                  <xsl:call-template name="CreateValidObjectName">
                    <xsl:with-param name="input-name" select="@name"/>
                  </xsl:call-template>
                </name>
                <file><xsl:value-of select="@name"/></file>
              </cert-object>
            </xsl:if>
          </xsl:for-each>
        </xsl:variable>

        <!-- create all of the certificate objects -->
        <xsl:for-each select="$cert-objects/*">
          <xsl:value-of select="concat('no certificate ', dpfunc:quoesc(./name), $eol,
                                'certificate ', dpfunc:quoesc(./name), ' ',
                                dpfunc:quoesc(concat($dirname, ./file)), ' ',
                                'ignore-expiration', $eol)"/>
        </xsl:for-each>

        <!-- create name of valcred from directory, and begin the object -->
        <xsl:variable name="valcred-object-name">
            <xsl:call-template name="CreateValidObjectName">
                <xsl:with-param name="input-name" select="$dirname"/>
            </xsl:call-template>
        </xsl:variable>
        <xsl:value-of select="concat('no valcred ', dpfunc:quoesc($valcred-object-name), $eol,
                              'valcred ', dpfunc:quoesc($valcred-object-name), $eol)"/>

        <!-- now add the certs to the valcred -->
        <xsl:for-each select="$cert-objects/*">
          <xsl:value-of select="concat('certificate ', dpfunc:quoesc(./name), $eol)"/>
        </xsl:for-each>

        <!-- exit valcred mode, and then exit crypto mode -->
        <xsl:value-of select="concat('exit', $eol, 'exit', $eol)"/>
    </xsl:template>

    <!-- implement error handling for the 'ValCredAddCertsFromDir' action -->
    <xsl:template mode="cli-error-processing"
        match="response[../args/screen='action' and ../args/action='ValCredAddCertsFromDir']">
        <!-- Since the creation of the certificate and valcred objects is asynchronous there
             almost certainly will be errors returned, either about objects being deleted which
             don't exist (from the generated "no" commands), or about objects not being up yet,
             etc.  And because it's asynchronous we can't check the OpState of the valcred
             because it's a race to see if it's up yet.  So just return OK and a message about
             checking the state of the object. -->
        <response>
          <result>OK</result>
          <details>If the Validation Credential is 'down' then one or more certificates may be
             expired or otherwise unusable; 'View Object Status' will show this
             information.</details>
        </response>
    </xsl:template>

    <!-- CryptoProfile -->
    <xsl:template mode="cli-delete-object" match="CryptoProfile">
        <xsl:call-template name="CryptoWrapper">
            <xsl:with-param name="cmdline">
                <xsl:value-of select="concat('no profile ', dpfunc:quoesc(@name), $eol)"/>
            </xsl:with-param>
        </xsl:call-template>
    </xsl:template>

    <xsl:template mode="cli-object" match="CryptoProfile">
        <xsl:call-template name="CryptoWrapper">
            <xsl:with-param name="cmdline">
                <xsl:choose>
                    <xsl:when test="string(IdentCredential) = ''">
                        <xsl:value-of select="concat('profile ', dpfunc:quoesc(@name), 
                                              ' ', $quote, '%none%', $quote)"/>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:value-of select="concat('profile ', dpfunc:quoesc(@name), 
                                              ' ', dpfunc:quoesc(IdentCredential))"/>
                    </xsl:otherwise>
                </xsl:choose>
                <xsl:if test="SSLOptions/*">
                    <xsl:value-of select="concat(' option-string ')"/>
                    <xsl:for-each select="SSLOptions/(custom|*[.='on'])">
                        <xsl:variable name="optionName" select="local-name()"/>
                        <xsl:choose>
                            <xsl:when test="$optionName='custom'">
                                <xsl:value-of select="."/>
                                <xsl:if test="position() != last()">
                                    <xsl:value-of select="'+'"/>
                                </xsl:if>
                            </xsl:when>
                            <xsl:otherwise>
                                <xsl:value-of select="$optionName"/>
                                <xsl:if test="position() != last()">
                                    <xsl:value-of select="'+'"/>
                                </xsl:if>
                            </xsl:otherwise>
                        </xsl:choose>
                    </xsl:for-each>
                </xsl:if>
                <xsl:apply-templates mode="CryptoProfile"/>
            </xsl:with-param>
        </xsl:call-template>
    </xsl:template>

    <xsl:template mode="CryptoProfile" match="IdentCredential|SSLOptions"/>    

    <!-- default inline crypto profile properties -->
    <xsl:template mode="CryptoProfile" match="*">
        <xsl:apply-templates mode="DefaultProperty" select=".">
            <xsl:with-param name="objName" select="name(..)"/>
            <xsl:with-param name="pName" select="name()"/>
            <xsl:with-param name="pValue" select="."/>
            <xsl:with-param name="Inline" select="''"/>
        </xsl:apply-templates>
    </xsl:template>
    
    <!-- CryptoEngine : Don't generate engine commands, the crypto
         engine is autodetected right now, and there is no 'no engine'
         command -->
    <xsl:template mode="cli-delete-object" match="CryptoEngine"/>
    <xsl:template mode="cli-object" match="CryptoEngine"/>

    <!-- CryptoFWCred -->
    <xsl:template mode="cli-delete-object" match="CryptoFWCred">
        <xsl:call-template name="CryptoWrapper">
            <xsl:with-param name="cmdline">
                <xsl:value-of select="concat('no fwcred ', dpfunc:quoesc(@name), $eol)"/>
            </xsl:with-param>
        </xsl:call-template>
    </xsl:template>

    <xsl:template mode="cli-object" match="CryptoFWCred">
        <xsl:call-template name="CryptoWrapper">
            <xsl:with-param name="cmdline">
                <xsl:value-of select="concat('fwcred ', dpfunc:quoesc(@name), $eol)"/>
                <xsl:if test="($delta-config=true())">
                    <xsl:value-of select="concat('    reset', $eol)"/>
                </xsl:if>
                <xsl:apply-templates mode="CryptoFWCred"/>
                <xsl:value-of select="concat('  exit')"/>
            </xsl:with-param>
        </xsl:call-template>
    </xsl:template>

    <xsl:template mode="CryptoFWCred" match="PrivateKey">
        <xsl:value-of select="concat('    key ', dpfunc:quoesc(text()), $eol)"/>
    </xsl:template>

    <xsl:template mode="CryptoFWCred" match="SharedSecretKey">
        <xsl:value-of select="concat('    sskey ', dpfunc:quoesc(text()), $eol)"/>
    </xsl:template>

    <xsl:template mode="CryptoFWCred" match="Certificate">
        <xsl:value-of select="concat('    certificate ', dpfunc:quoesc(text()), $eol)"/>
    </xsl:template>

    <xsl:template mode="CryptoFWCred" match="mAdminState">
        <xsl:apply-templates mode="CanonicalProperty" select="."/>
    </xsl:template>

    <!-- CertMonitor -->
    <!-- there is no 'no cert-monitor' command -->
    <xsl:template mode="cli-delete-object" match="CertMonitor"/>

    <xsl:template mode="cli-object" match="CertMonitor">
      <xsl:call-template name="CryptoWrapper">
        <xsl:with-param name="cmdline">
          <xsl:apply-templates mode="CanonicalObject" select="."/>
        </xsl:with-param>
      </xsl:call-template>
    </xsl:template>

    <!-- Kerberos KDC -->
    <xsl:template mode="cli-object" match="CryptoKerberosKDC">
      <xsl:call-template name="CryptoWrapper">
        <xsl:with-param name="cmdline">
          <xsl:apply-templates mode="CanonicalObject" select="."/>
        </xsl:with-param>
      </xsl:call-template>
    </xsl:template>

    <xsl:template mode="cli-delete-object" match="CryptoKerberosKDC">
      <xsl:call-template name="CryptoWrapper">
        <xsl:with-param name="cmdline">
            <xsl:value-of select="concat('no kerberos-kdc ', @name, $eol)"/>
        </xsl:with-param>
      </xsl:call-template>
    </xsl:template>

    <!-- Kerberos Keytab -->
    <xsl:template mode="cli-object" match="CryptoKerberosKeytab">
      <xsl:call-template name="CryptoWrapper">
        <xsl:with-param name="cmdline">
          <xsl:apply-templates mode="CanonicalObject" select="."/>
        </xsl:with-param>
      </xsl:call-template>
    </xsl:template>

    <xsl:template mode="cli-delete-object" match="CryptoKerberosKeytab">
      <xsl:call-template name="CryptoWrapper">
        <xsl:with-param name="cmdline">
          <xsl:value-of select="concat('no kerberos-keytab ', @name, $eol)"/>
        </xsl:with-param>
      </xsl:call-template>
    </xsl:template>

    <!-- ************************************************************ -->
    <!-- MQGW -->
    <!-- ************************************************************ -->
    <xsl:template mode="cli-object" match="MQGW">
        <xsl:call-template name="available-open">
            <xsl:with-param name="name" select="local-name()"/>
        </xsl:call-template>

        <xsl:value-of select="concat($eol, 'mq-node', ' ', dpfunc:quoesc(@name), $eol)"/>
        <xsl:if test="($delta-config=true())">
            <xsl:value-of select="concat(' reset', $eol)"/>
        </xsl:if>

        <xsl:apply-templates mode="MQGW"/>
        <xsl:value-of select="concat('exit', $eol)"/>
        <xsl:call-template name="available-close">
            <xsl:with-param name="name" select="local-name()"/>
        </xsl:call-template>

    </xsl:template>

    <xsl:template mode="MQGW" match="Client">
        <xsl:if test="(string-length()!=0)">
            <xsl:if test="(../Direction='HTTP2MQ') or ((../Direction='') and (ClientTransportType='mq'))">
                <xsl:value-of select="concat(' client mq ', ClientGetQueue, ' ', ClientPutQueue, $eol)"/>
            </xsl:if>
            <xsl:if test="(../Direction='MQ2HTTP') or ((../Direction='') and (ClientTransportType='http'))">
                <xsl:value-of select="concat(' client http ', ClientPort, $eol)"/>
            </xsl:if>
        </xsl:if>
    </xsl:template>

    <xsl:template mode="MQGW" match="Server">
        <xsl:if test="(string-length()!=0)">
            <xsl:if test="(../Direction='MQ2HTTP') or ((../Direction='') and (ServerTransportType='mq'))">
                <xsl:value-of select="concat(' server mq ', ServerGetQueue, ' ', ServerPutQueue, $eol)"/>
            </xsl:if>
            <xsl:if test="(../Direction='HTTP2MQ') or ((../Direction='') and (ServerTransportType='http'))">
                <xsl:value-of select="concat(' server http ', ServerPort, $eol)"/>
            </xsl:if>
        </xsl:if>
    </xsl:template>

    <xsl:template mode="MQGW" match="*">
        <xsl:apply-templates mode="DefaultProperty" select=".">
            <xsl:with-param name="objName" select="name(..)"/>
            <xsl:with-param name="pName" select="name()"/>
            <xsl:with-param name="pValue" select="."/>
        </xsl:apply-templates>
    </xsl:template>

    <!-- ************************************************************ -->
    <!-- Intrinsic LogLabel -->
    <!-- ************************************************************ -->
    
    <xsl:template mode="cli-object" match="LogLabel[@intrinsic='true']"/>
    
    <!-- ************************************************************ -->
    <!-- LogTarget -->
    <!-- ************************************************************ -->
    
    <xsl:template mode="cli-object" match="LogTarget">
        <xsl:choose>
            <!-- if 'default-log' - only allow changes to event and object subscription -->
            <xsl:when test="(@name='default-log')">
                <xsl:value-of select="concat($eol, 'no logging event default-log *', $eol )"/>
                <xsl:value-of select="concat($eol, 'no logging eventcode default-log *', $eol )"/>
                <xsl:value-of select="concat($eol, 'no logging eventfilter default-log *', $eol )"/>
                <xsl:apply-templates mode="DefaultLogTarget"/>
            </xsl:when>
            
            <xsl:otherwise>
                <xsl:value-of select="concat($eol, 'logging target ', dpfunc:quoesc(@name), $eol)"/>                
                <xsl:if test="($delta-config=true())">
                    <xsl:value-of select="concat($eol, '  reset', $eol)"/>
                </xsl:if>                
                <xsl:apply-templates mode="LogTarget"/>                
                <xsl:value-of select="concat('exit', $eol)"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <!-- suppress internal property -->
    <xsl:template mode="LogTarget" match="Stream"/>
    
    <xsl:template mode="LogTarget" match="RemoteAddress">
        <xsl:if test="(string-length()!=0)">
            <xsl:value-of select="concat('  remote-address ', text(), ' ', ../RemotePort, $eol)"/>
        </xsl:if>
    </xsl:template>
    
    <xsl:template mode="LogTarget" match="RemotePort"/>
  
    <xsl:template mode="LogTarget" match="SigningMode">
        <xsl:if test="(text()='on')">
            <xsl:value-of select="concat('  sign ', ../IdentCredential, ' ', ../SignAlgorithm, $eol)"/>
        </xsl:if>
    </xsl:template>
  
    <xsl:template mode="LogTarget" match="IdentCredential"/>
    <xsl:template mode="LogTarget" match="SignAlgorithm"/>
    
    <xsl:template mode="LogTarget" match="EncryptMode">
        <xsl:if test="(text()='on')">
            <xsl:value-of select="concat('  encrypt ', ../Cert, ' ', ../EncryptAlgorithm, $eol)"/>
        </xsl:if>
    </xsl:template>
  
    <xsl:template mode="LogTarget" match="Cert"/>
    <xsl:template mode="LogTarget" match="EncryptAlgorithm"/>
    
    <xsl:template mode="LogTarget" match="RemoteLogin">
        <xsl:if test="(../ArchiveMode/text()='upload') and not (../UploadMethod/text()='smtp')">
            <xsl:value-of select="concat('  remote-login ', dpfunc:quoesc(text()))"/>
            <xsl:if test="(../RemotePassword) and ($delta-config=true()) and not(../RemotePassword/text()='')">
                <xsl:value-of select="concat(' ', ../RemotePassword)"/>                                     
            </xsl:if>
            <xsl:value-of select="concat($eol)"/>                                     
        </xsl:if>
    </xsl:template>

    <xsl:template mode="LogTarget" match="RemotePassword"/>
    
    <xsl:template mode="LogTarget" match="LogEvents">
        <xsl:value-of select="concat( '  event ', Class, ' ', Priority, $eol )"/>
    </xsl:template>

    <xsl:template mode="LogTarget" match="LogObjects">
        <xsl:value-of select="concat( '  object ', Class, ' ', Object, $eol )"/>
        <xsl:if test="FollowReferences='on'">
            <xsl:call-template name="Log-ReferenceChain">
                <xsl:with-param name="objClass" select="Class"/>
                <xsl:with-param name="objName" select="Object"/>
            </xsl:call-template>
        </xsl:if>
    </xsl:template>

    <xsl:template mode="DefaultLogTarget" match="LogEvents[not(Class = 'webgui')]">
        <xsl:value-of select="concat( 'logging event default-log ', Class, ' ', Priority, $eol )"/>
    </xsl:template>

    <xsl:template mode="DefaultLogTarget" match="LogEventCode">
        <xsl:value-of select="concat( 'logging eventcode default-log ', text(), $eol )"/>
    </xsl:template>

    <xsl:template mode="DefaultLogTarget" match="LogEventFilter">
        <xsl:value-of select="concat( 'logging eventfilter default-log ', text(), $eol )"/>
    </xsl:template>

    <xsl:template name="Log-ReferenceChain">
        <xsl:param name="objClass" select="''"/>
        <xsl:param name="objName" select="''"/>
        <xsl:param name="prefix" select="'  '"/>
        <xsl:param name="target" select="''"/>
        <xsl:apply-templates mode="Log-FindReference"
          select="$config-objects-index/self::object[@name=$objClass]/ancestor-or-self::*/properties/property[@type='dmReference']">
            <xsl:with-param name="objClass" select="$objClass"/>
            <xsl:with-param name="objName" select="$objName"/>
            <xsl:with-param name="prefix" select="$prefix"/>
            <xsl:with-param name="target" select="$target"/>
        </xsl:apply-templates>
    </xsl:template>
    
    <xsl:template mode="Log-FindReference" match="*">
        <xsl:param name="objClass" select="''"/>
        <xsl:param name="objName" select="''"/>
        <xsl:param name="objName" select="''"/>
        <xsl:param name="prefix" select="'  '"/>
        <xsl:param name="target" select="''"/>
        <xsl:variable name="refType" select="@reftype"/>
        <xsl:variable name="refName"
          select="$cli-existing/response/operation[@type='get-config'] 
                  /configuration/*[(local-name()=$objClass) and (@name=$objName)]/*[local-name()=$refType]"/>
        <xsl:if test="$refName">
            <xsl:value-of select="concat( $prefix, 'object ', $target ,$refType, ' ', $refName, $eol )"/>
            <xsl:call-template name="Log-ReferenceChain">
                <xsl:with-param name="objClass" select="$refType"/>
                <xsl:with-param name="objName" select="$refName"/>
                <xsl:with-param name="prefix" select="$prefix"/>
                <xsl:with-param name="target" select="$target"/>
            </xsl:call-template>
        </xsl:if>
    </xsl:template>
  
    <xsl:template mode="LogTarget" match="*">
        <xsl:apply-templates mode="CanonicalProperty" select="."/>
    </xsl:template>

    <!-- ************************************************************ -->
    <!-- SSHService -->
    <!-- ************************************************************ -->
    
    <xsl:template mode="cli-delete-object" match="SSHService"/>

    <xsl:template mode="cli-object" match="SSHService">
        <!-- enable/disable -->
        <xsl:choose>
            <xsl:when test="(mAdminState='enabled')">
                <xsl:value-of select="concat($eol, 'ssh ', LocalAddress, ' ', LocalPort, $eol)"/>
            </xsl:when>
            <xsl:when test="(mAdminState='disabled')">
                <xsl:value-of select="concat($eol, 'no ssh', $eol)"/>
            </xsl:when>
        </xsl:choose>
    </xsl:template>

    <!-- ************************************************************ -->
    <!-- ACL -->
    <!-- ************************************************************ -->
    
    <xsl:template mode="cli-delete-object" match="AccessControlList">
        <xsl:value-of select="concat($eol, 'no acl ', @name, $eol)"/>
    </xsl:template>

    <xsl:template mode="cli-object" match="AccessControlList">
        <!-- preserve the ACL even if SSH is disabled -->
        <xsl:value-of select="concat($eol, 'acl ', @name, $eol)"/>
        <xsl:if test="($delta-config=true())">
            <xsl:value-of select="concat('  reset', $eol)"/>
        </xsl:if>
        <xsl:apply-templates mode="ACLEntry" select="*"/>
        <xsl:value-of select="concat('exit', $eol)"/>
    </xsl:template>

    <xsl:template mode="ACLEntry" match="AccessControlEntry">
        <xsl:value-of select="concat('  ', Access, ' ', Address, $eol)"/>
    </xsl:template>
    
    <xsl:template mode="ACLEntry" match="mAdminState">
        <xsl:apply-templates mode="CanonicalProperty" select="."/>
    </xsl:template>
    
    <!-- ************************************************************ -->
    <!-- Packet Capture -->
    <!-- ************************************************************ -->
    
    <xsl:template mode="cli-delete-object" match="xmltrace"/>

    <xsl:template mode="cli-object" match="xmltrace">
        <!-- enable/disable -->
        <xsl:if test="($delta-config=true())">
            <xsl:value-of select="concat($eol, 'file-capture ', Mode, $eol)"/>
        </xsl:if>
    </xsl:template>

    <!-- ************************************************************ -->
    <!-- Statistics -->
    <!-- ************************************************************ -->
    
    <xsl:template mode="cli-delete-object" match="Statistics"/>

    <xsl:template mode="cli-object" match="Statistics">
        <!-- enable/disable -->
        <xsl:choose>
            <xsl:when test="(mAdminState='enabled')">
                <xsl:value-of select="concat($eol, 'statistics', $eol)"/>
            </xsl:when>
            <xsl:when test="(mAdminState='disabled')">
                <xsl:value-of select="concat($eol, 'no statistics', $eol)"/>
            </xsl:when>
        </xsl:choose>
        <xsl:apply-templates mode="Statistics"/>
    </xsl:template>

    <xsl:template mode="Statistics" match="LoadInterval">
        <xsl:apply-templates mode="DefaultProperty" select=".">
            <xsl:with-param name="objName" select="name(..)"/>
            <xsl:with-param name="pName" select="name()"/>
            <xsl:with-param name="pValue" select="."/>
            <xsl:with-param name="Indent" select="$eol"/>
        </xsl:apply-templates>
    </xsl:template>

    <!-- ************************************************************ -->
    <!-- Error Report Settings -->
    <!-- ************************************************************ -->
    
    <xsl:template mode="cli-object" match="ErrorReportSettings">
        <xsl:value-of select="concat($eol, 'failure-notification', $eol)"/>
        <xsl:if test="($delta-config=true())">
            <xsl:value-of select="concat('  reset', $eol)"/>
        </xsl:if>
        <xsl:apply-templates mode="ErrorReportSettings"/>
        <xsl:value-of select="concat('exit', $eol)"/>
        
        <xsl:if test="$delta-config=false()">
            <xsl:if test="(mAdminState='enabled')">
                <xsl:choose>
                    <xsl:when test="(UseSmtp = 'on')">
                        <xsl:value-of select="concat($eol, 
                                                     'send error-report', 
                                                     ' ', dpfunc:quoesc(SmtpServer),
                                                     ' ', dpfunc:quoesc(LocationIdentifier),
                                                     ' ', dpfunc:quoesc(EmailAddress), $eol)"/>
                    </xsl:when>

                    <xsl:otherwise>
                        <xsl:value-of select="$eol"/>
                        <xsl:if test="(AlwaysOnStartup = 'off')">
                            <xsl:value-of select="concat('%if% isfile temporary:///backtrace', $eol)"/>
                        </xsl:if>
                        <xsl:if test="(InternalState = 'on')">
                            <xsl:value-of select="concat('save internal-state', $eol)"/>
                        </xsl:if>
                        <xsl:value-of select="concat('save error-report', $eol)"/>
                        <xsl:if test="(AlwaysOnStartup = 'off')">
                            <xsl:value-of select="concat('%endif%', $eol)"/>
                        </xsl:if>
                        <xsl:value-of select="$eol"/>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:if>
        </xsl:if>
    </xsl:template>
    
    <xsl:template mode="ErrorReportSettings" match="mAdminState">
      <xsl:value-of select="concat('  admin-state ', text(), $eol)"/>
    </xsl:template>
    
    <xsl:template mode="ErrorReportSettings" match="*">
        <xsl:apply-templates mode="CanonicalProperty" select="."/>
    </xsl:template>

    <!-- ************************************************************ -->
    <!-- HTTPUserAgent -->
    <!-- ************************************************************ -->
    
    <xsl:template mode="cli-delete-object" match="HTTPUserAgent">
      <xsl:value-of select="concat($eol, 'no user-agent ', dpfunc:quoesc(@name), $eol)"/>
    </xsl:template>

    <xsl:template mode="cli-object" match="HTTPUserAgent">
        <xsl:value-of select="concat($eol, 'user-agent ', dpfunc:quoesc(@name), $eol)"/>
        <xsl:if test="($delta-config=true())">
            <xsl:value-of select="concat('  reset', $eol)"/>
        </xsl:if>
        <xsl:apply-templates mode="HTTPUserAgent"/>
        <xsl:value-of select="concat('exit', $eol)"/>
    </xsl:template>

    <xsl:template mode="HTTPUserAgent" match="ProxyPolicies">
        <xsl:value-of select="concat('  proxy ', dpfunc:quoesc(RegExp))"/>
        <xsl:choose>
            <xsl:when test="(Skip='off')">
                <xsl:value-of select="concat(' ', RemoteAddress, ' ', RemotePort)"/>        
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="concat(' none')"/>        
            </xsl:otherwise>
        </xsl:choose>
        <xsl:value-of select="concat($eol)"/>        
    </xsl:template>

    <xsl:template mode="HTTPUserAgent" match="SSLPolicies">
        <xsl:value-of select="concat('  ssl ', dpfunc:quoesc(RegExp), ' ',
                              dpfunc:quoesc(SSLProxyProfile), $eol)"/>
    </xsl:template>

    <xsl:template mode="HTTPUserAgent" match="BasicAuthPolicies">
        <xsl:value-of select="concat('  basicauth ', dpfunc:quoesc(RegExp), ' ',
                              dpfunc:quoesc(UserName), ' ',
                              dpfunc:quoesc(Password), $eol)"/>
    </xsl:template>

    <xsl:template mode="HTTPUserAgent" match="SoapActionPolicies">
        <xsl:value-of select="concat('  soapaction ', dpfunc:quoesc(RegExp), ' ',
                              dpfunc:quoesc(SoapAction), $eol)"/>
    </xsl:template>

    <xsl:template mode="HTTPUserAgent" match="AllowCompressionPolicies">
        <xsl:value-of select="concat('  compression-policy ', dpfunc:quoesc(RegExp), ' ',
                              dpfunc:quoesc(AllowCompression), $eol)"/>
    </xsl:template>

    <xsl:template mode="HTTPUserAgent" match="Restrict10Policies">
        <xsl:value-of select="concat('  restrict-http-policy ', dpfunc:quoesc(RegExp), ' ',
                              dpfunc:quoesc(Restrict10), $eol)"/>
    </xsl:template>

    <xsl:template mode="HTTPUserAgent" match="AddHeaderPolicies">
        <xsl:value-of select="concat('  add-header-policy ', dpfunc:quoesc(RegExp), ' ',
                              dpfunc:quoesc(AddHeader), ' ', dpfunc:quoesc(AddValue), $eol)"/>
    </xsl:template>

    <xsl:template mode="HTTPUserAgent" match="UploadChunkedPolicies">
        <xsl:value-of select="concat('  chunked-uploads-policy ', dpfunc:quoesc(RegExp), ' ',
                              dpfunc:quoesc(UploadChunked), $eol)"/>
    </xsl:template>
    
   <xsl:template mode="HTTPUserAgent" match="*">
        <xsl:apply-templates mode="DefaultProperty" select=".">
            <xsl:with-param name="objName" select="name(..)"/>
            <xsl:with-param name="pName" select="name()"/>
            <xsl:with-param name="pValue" select="."/>
            <xsl:with-param name="Indent" select="'  '"/>
        </xsl:apply-templates>
    </xsl:template>
    
    <!-- ************************************************************ -->
    <!-- WebGUI -->
    <!-- ************************************************************ -->
    
    <xsl:template mode="cli-delete-object" match="WebGUI"/>

    <xsl:template mode="cli-object" match="WebGUI">
        <xsl:choose>
            <xsl:when test="(SaveConfigOverwrites='on')">
                <xsl:value-of select="concat($eol, 'save-config overwrite', $eol)"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="concat($eol, 'no save-config overwrite', $eol)"/>
            </xsl:otherwise>
        </xsl:choose>
        
        <xsl:value-of select="concat($eol, 'web-mgmt', $eol)"/>
        <xsl:if test="($delta-config=true())">
            <xsl:value-of select="concat('  reset', $eol)"/>
        </xsl:if>
        <xsl:apply-templates mode="WebGUI"/>
        <xsl:value-of select="concat('exit', $eol)"/>            
    </xsl:template>

    <!-- local-address + local-port properties -->
    <xsl:template mode="WebGUI" match="LocalAddress">
        <xsl:value-of select="concat('  local-address ', text(), ' ', ../LocalPort, $eol)"/>
    </xsl:template>

    <xsl:template mode="WebGUI" match="LocalPort"/>

    <xsl:template mode="WebGUI" match="mAdminState">
      <xsl:value-of select="concat('  admin-state ', text(), $eol)"/>
    </xsl:template>
    
    <xsl:template mode="WebGUI" match="*">
        <xsl:apply-templates mode="CanonicalProperty" select="."/>
    </xsl:template>
    
    <!-- ************************************************************ -->
    <!-- MgmtInterface -->
    <!-- ************************************************************ -->
    
    <xsl:template mode="cli-delete-object" match="MgmtInterface"/>

    <xsl:template mode="cli-object" match="MgmtInterface">
        <xsl:value-of select="concat($eol, 'xml-mgmt', $eol)"/>
        <xsl:if test="($delta-config=true())">
            <xsl:value-of select="concat('  reset', $eol)"/>
        </xsl:if>
        <xsl:apply-templates mode="XMLMgmt"/>
        <xsl:value-of select="concat('exit', $eol)"/>            
    </xsl:template>

    <!-- local-address + local-port properties -->
    <xsl:template mode="XMLMgmt" match="LocalAddress">
        <xsl:value-of select="concat('  local-address ', text(), ' ', ../LocalPort, $eol)"/>
    </xsl:template>
    
    <xsl:template mode="XMLMgmt" match="LocalPort"/>
    
    <xsl:template mode="XMLMgmt" match="mAdminState">
      <xsl:value-of select="concat('  admin-state ', text(), $eol)"/>
    </xsl:template>

    <xsl:template mode="XMLMgmt" match="*">
        <xsl:apply-templates mode="CanonicalProperty" select="."/>
    </xsl:template>
    
    <!-- ************************************************************ -->
    <!-- http proxy templates -->
    <!-- ************************************************************ -->
  
    <xsl:template name="HTTPProxyServiceProperties">
        <xsl:param name="identifier" select="''"/>
        <xsl:value-of select="concat($eol, 'http ', dpfunc:quoesc(@name), ' ', $identifier, $eol)"/>
        <xsl:apply-templates mode="HTTPProxyService"/>
        <xsl:value-of select="concat('exit', $eol )"/>
    </xsl:template>
    
    <!-- http header injection -->
    <xsl:template mode="HTTPProxyService" match="HeaderInjection">
        <xsl:value-of select="concat('  inject ', Direction, 
                                     ' ', dpfunc:quoesc(HeaderTag), 
                                     ' ', dpfunc:quoesc(HeaderTagValue), $eol)"/>
    </xsl:template>
    
    <!-- http header suppress -->
    <xsl:template mode="HTTPProxyService" match="HeaderSuppression">
        <xsl:value-of select="concat('  suppress ', Direction, 
                                     ' ', dpfunc:quoesc(HeaderTag), $eol)"/>
    </xsl:template>
    
    <!-- http version -->
    <xsl:template mode="HTTPProxyService" match="HTTPVersion">
        <xsl:value-of select="concat('  version ', Front, ' ', Back, $eol)"/>
    </xsl:template>
    
    <!-- host rewriting -->
    <xsl:template mode="HTTPProxyService" match="DoHostRewrite">
        <xsl:value-of select="concat('  host-rewriting ', text(), $eol)"/>
    </xsl:template>
    
    <xsl:template mode="HTTPProxyService" match="HTTPIncludeResponseTypeEncoding">
        <!-- enable/disable -->
        <xsl:if test="(text()='on')">
                <xsl:value-of select="concat('  include-response-type-encoding', $eol)"/>
        </xsl:if>
        <xsl:if test="(text()='off')">
                <xsl:value-of select="concat('  no include-response-type-encoding', $eol)"/>
        </xsl:if>
    </xsl:template>

    <xsl:template mode="HTTPProxyService" match="AlwaysShowErrors">
        <!-- enable/disable -->
        <xsl:if test="(text()='on')">
                <xsl:value-of select="concat('  always-show-errors', $eol)"/>
        </xsl:if>
        <xsl:if test="(text()='off')">
                <xsl:value-of select="concat('  no always-show-errors', $eol)"/>
        </xsl:if>
    </xsl:template>

    <xsl:template mode="HTTPProxyService" match="DisallowGet">
        <!-- enable/disable -->
        <xsl:if test="(text()='on')">
                <xsl:value-of select="concat('  disallow-get', $eol)"/>
        </xsl:if>
        <xsl:if test="(text()='off')">
                <xsl:value-of select="concat('  no disallow-get', $eol)"/>
        </xsl:if>
    </xsl:template>

    <xsl:template mode="HTTPProxyService" match="DisallowEmptyResponse">
        <!-- enable/disable -->
        <xsl:if test="(text()='on')">
                <xsl:value-of select="concat('  disallow-empty-reply', $eol)"/>
        </xsl:if>
        <xsl:if test="(text()='off')">
                <xsl:value-of select="concat('  no disallow-empty-reply', $eol)"/>
        </xsl:if>
    </xsl:template>


    <!-- remaining properties in external http submenu -->
    <xsl:template mode="HTTPProxyService" match="HTTPTimeout|HTTPPersistTimeout|SuppressHTTPWarnings
                                                 |HTTPCompression|HTTPPersistentConnections|HTTPClientIPLabel
                                                 |HTTPProxyHost|HTTPProxyPort">
        <xsl:apply-templates mode="DefaultProperty" select=".">
            <xsl:with-param name="objName" select="'HTTPProxyService'"/>
            <xsl:with-param name="pName" select="name()"/>
            <xsl:with-param name="pValue" select="text()"/>
            <xsl:with-param name="Indent" select="'  '"/>
        </xsl:apply-templates>
    </xsl:template>

    <xsl:template mode="HTTPProxyService" match="DoChunkedUpload">
        <xsl:apply-templates mode="CanonicalProperty" select="."/>
    </xsl:template>
        
    <xsl:template mode="HTTPProxyService" match="*"/>

    <!-- ************************************************************ -->
    <!-- domain templates -->
    <!-- ************************************************************ -->

    <xsl:template mode="cli-object" match="Domain">
        <xsl:if test="not(@name='default')">
            <xsl:apply-templates mode="CanonicalObject" select="."/>
        </xsl:if>
    </xsl:template>

    <!-- ************************************************************ -->
    <!-- DNSNameservice templates -->
    <!-- ************************************************************ -->
    <xsl:template mode="cli-delete-object" match="DNSNameService"/>

    <xsl:template mode="cli-object" match="DNSNameService">
    	<xsl:value-of select="concat($eol, 'dns', $eol)"/>
        <xsl:if test="($delta-config=true())">
	    <xsl:value-of select="concat('  reset',$eol)"/>
        </xsl:if>
        <xsl:apply-templates mode="DNSNameService"/>
	<xsl:value-of select="concat('exit', $eol)"/>
    </xsl:template>
    
    <xsl:template mode="DNSNameService" match="SearchDomains">
        <xsl:value-of select="concat('  search-domain ', dpfunc:quoesc(SearchDomain), $eol)"/>
    </xsl:template>
    
    <xsl:template mode="DNSNameService" match="NameServers">
        <!-- hardwire the hidden Flags property to its default value -->
        <xsl:value-of select="concat('  name-server ', IPAddress, ' ', UDPPort, ' ', TCPPort, ' 0 ', MaxRetries, $eol)"/>
    </xsl:template>
    
    <xsl:template mode="DNSNameService" match="StaticHosts">
        <xsl:value-of select="concat('  static-host ', dpfunc:quoesc(Hostname), ' ', IPAddress, $eol)"/>
    </xsl:template>

    <xsl:template mode="DNSNameService" match="mAdminState">
        <xsl:apply-templates mode="CanonicalProperty" select="."/>
    </xsl:template>

    <!-- ************************************************************ -->
    <!-- SystemSettings templates -->
    <!-- ************************************************************ -->
    <xsl:template mode="cli-delete-object" match="SystemSettings"/>

    <!-- ************************************************************ -->
    <!-- autogenerated object templates (low priority) -->
    <!-- ************************************************************ -->

    <!-- auto-generated config -->
    <xsl:template mode="cli-object" priority="-100" match="*[$config-objects-index/self::object/@name=local-name()]">
        <xsl:choose>
            <xsl:when test="$config-objects-index/self::object[@name=local-name() and @custom-cli='true']">
                <xsl:message dp:priority="warn">
                    <xsl:text>No cli-object template found for custom cli syntax of '</xsl:text>
                    <xsl:value-of select="local-name()"/>
                    <xsl:text>'</xsl:text>
                </xsl:message>
            </xsl:when>
            <xsl:otherwise>
                <xsl:apply-templates mode="CanonicalObject" select="."/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
        
    <!-- ************************************************************ -->
    <!-- canonical object templates -->
    <!-- ************************************************************ -->

    <xsl:template mode="CanonicalObject" match="*">
        <xsl:variable name="objName" select="local-name()"/>
        <xsl:variable name="pNode" select="$config-objects-index/self::object[@name=$objName]"/>

        <xsl:variable name="alias" select="$pNode/cli-alias"/>

        <!-- skip unpersisted objects in save config mode -->
        <xsl:if test="not($pNode/@persisted='false') or $delta-config">
                         
            <!-- singletons do not have name serialized -->
            <xsl:variable name="singleton_or_name">
                <xsl:if test="not($pNode/@singleton = 'true' or $pNode/@domain-singleton = 'true')"> 
                    <xsl:value-of select="concat(' ', dpfunc:quoesc(@name))"/>
                </xsl:if>
            </xsl:variable>

            <!-- start object conditional -->
            <xsl:call-template name="available-open">
                <xsl:with-param name="name" select="local-name()"/>
                <xsl:with-param name="pNode" select="$pNode"/>
            </xsl:call-template>
       
            <!-- enter object mode -->
            <xsl:value-of select="concat($eol, $alias, $singleton_or_name, $eol)"/>

            <xsl:if test="($delta-config=true()) and ((./@reset!='false') or not(./@reset))">
                <xsl:value-of select="concat('  reset', $eol)"/>
            </xsl:if>        
            
            <!-- object with non-distinct vector property -->
            <xsl:if test="(not(@reset='false') and $pNode//property[@vector='true' and @distinct='false'])">
                <xsl:for-each select="$pNode//property[@vector='true' and @distinct='false']">
                   <xsl:value-of select="concat('  no ',./cli-alias,$eol)"/>
                </xsl:for-each>
            </xsl:if>        

            <!-- serialize properties -->
            <xsl:apply-templates mode="CanonicalProperty"/>                                       

            <!-- exit object mode -->                                                             
            <xsl:value-of select="concat('exit', $eol)"/>

            <!-- end object conditional -->
            <xsl:call-template name="available-close">
                <xsl:with-param name="name" select="local-name()"/>
                <xsl:with-param name="pNode" select="$pNode"/>
            </xsl:call-template>

        </xsl:if>

    </xsl:template>

    <!-- pseudo property that is really a container for other props -->
    <xsl:template mode="CanonicalProperty" match="*[MetaItemVector]">
        <xsl:for-each select=".//MetaItem">
            <xsl:choose>
                <xsl:when test="DataSource">
                    <xsl:value-of select="concat('  meta-item ', dpfunc:quoesc(MetaCategory), ' ', dpfunc:quoesc(MetaName), ' ', dpfunc:quoesc(DataSource), $eol)"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="concat('  meta-item ', dpfunc:quoesc(MetaCategory), ' ', dpfunc:quoesc(MetaName), $eol)"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:for-each>
    </xsl:template>

    <!-- canonical property -->
    <xsl:template mode="CanonicalProperty" match="*">
        <xsl:apply-templates mode="DefaultProperty" select=".">
            <xsl:with-param name="objName" select="name(..)"/>
            <xsl:with-param name="pName" select="name()"/>
            <xsl:with-param name="pValue" select="text()"/>
            <xsl:with-param name="pProp" select="."/>
            <xsl:with-param name="Indent" select="'  '"/>
        </xsl:apply-templates>
    </xsl:template>


  <!-- ************************************************************ -->
  <!-- Generic helper templates -->
  <!-- ************************************************************ -->

  <!-- issues %if% available prelude for first object of its kind -->
  <!-- NOTE must be called with config object as context node. -->
  <xsl:template name="available-open">
      <xsl:param name="name" select="local-name()"/>
      <xsl:param name="pNode" select="$config-objects-index/self::object[@name=$name]"/>
      <xsl:param name="alias" select="$pNode/cli-alias"/>
      
      <xsl:variable name="isFirst" select="not(preceding-sibling::*[1][local-name()=$name])"/>

      <xsl:if test="$isFirst">
          <xsl:value-of select="concat($eol, '%if% available ', dpfunc:quoesc($alias), $eol)"/>
      </xsl:if>
  </xsl:template>

  <xsl:template name="available-close">
      <xsl:param name="name" select="local-name()"/>
      <xsl:param name="pNode" select="$config-objects-index/self::object[@name=$name]"/>
      
      <xsl:variable name="isLast" select="not(following-sibling::*[1][local-name()=$name])"/>

      <xsl:if test="$isLast">
          <xsl:value-of select="concat($eol, '%endif%', $eol)"/>
      </xsl:if>
  </xsl:template>

  <func:function name="dpfunc:esc">
      <xsl:param name="value"/>

      <!-- cli commands can't have carriage-returns or line-feeds in them (in any order or combination) -->
      <!-- don't use normalize-space() since it would alter with string literals with multiple spaces in them -->
      <xsl:variable name="find-crlf"><xsl:text>[\r\n]+</xsl:text></xsl:variable>
      <xsl:variable name="replace-crlf"><xsl:text> </xsl:text></xsl:variable>
      <xsl:variable name="stripped-value" select="regexp:replace($value, $find-crlf, 'g', $replace-crlf)"/>

      <xsl:variable name="find"><xsl:text>([\\"])</xsl:text></xsl:variable>
      <xsl:variable name="replace"><xsl:text>\$1</xsl:text></xsl:variable>
      <xsl:variable name="escaped-value" select="regexp:replace($stripped-value, $find, 'g', $replace)"/>

      <func:result select="$escaped-value"/>

  </func:function>

  <!-- if you're going to quote a string, you must escape it, in case there is a quote in it -->
  <func:function name="dpfunc:quoesc">
      <xsl:param name="value"/>
      <xsl:variable name="quoted-escaped-value" select="concat($quote, dpfunc:esc($value), $quote)"/>
      <func:result select="$quoted-escaped-value"/>
  </func:function>

    <func:function name="dpfunc:bitmap-to-string">
      <xsl:param name="bitmap"/>
      <xsl:variable name="result">
        <xsl:for-each select="$bitmap/*[.='on']">
          <xsl:value-of select="local-name()"/>
          <xsl:if test="position() != last()">+</xsl:if>
        </xsl:for-each>
      </xsl:variable>
      <func:result select="$result"/>
    </func:function>

  <!-- this is the default delete template, which works for objects
       which take 'no <cli-alias> @name' syntax -->

  <xsl:template mode="cli-delete-object" match="*" priority="-100">
      <xsl:variable name="objName" select="local-name()"/>
      <xsl:variable name="pNode" select="$config-objects-index/self::object[@name=$objName]"/>
      <xsl:choose>
          <xsl:when test="(not($pNode/cli-alias) or $pNode/cli-alias='')">
              <xsl:message dp:priority="warn">
                  <xsl:text>No cli-delete-object template for '</xsl:text>
                  <xsl:value-of select="$objName"/>
                  <xsl:text>'</xsl:text>
              </xsl:message>
          </xsl:when>
          <xsl:when test="($pNode/@singleton='true' or $pNode/@domain-singleton='true')">
              <xsl:value-of select="concat('no ', $pNode/cli-alias, $eol)"/>
          </xsl:when>
          <xsl:otherwise>
              <xsl:value-of select="concat('no ', $pNode/cli-alias, ' ', @name, $eol)"/>
          </xsl:otherwise>
      </xsl:choose>
      
  </xsl:template>

  <!-- meta-input suppression list -->
  <!-- List all form meta-inputs that are not XML Configuration here. -->
  <xsl:template mode="cli-delete-object" match="session
                                                  |action
                                                  |prevAction
                                                  |screen
                                                  |prevScreen
                                                  |requestClass
                                                  |prevClass
                                                  |requestName
                                                  |prevName
                                                  |requestDomain
                                                  |prevDomain
                                                  |skipNav
                                                  |prevNavArea
                                                  |newObjPopup
                                                  |newObjPopupInput
                                                  |editObjPopup
                                                  |directionRadio
                                                  |configDefStylesheet
                                                  |policyNameSelect
                                                  |focusOnInputId
                                                  |scrollToId
                                                  |scrollToIdOffset
                                                  |newObjPopupFileLocationInput
                                                  |editObjPopupInput
                                                  |currentTab
                                                  |accesslevel
                                                  |objectStatusRequestClass
                                                  |bNeedsSavedConfig
                                                  |prevNavItem" />

  <!-- Default property, called if property is set outside of object in sub menu / cmd line / inline -->
  <xsl:template mode="DefaultProperty" match="*">
    <!-- objAlias: external menu name to be invoked (optional) -->
    <xsl:param name="objAlias" select="''"/>
    <!-- objName: name of object definition in schema (required) -->
    <xsl:param name="objName" select="''"/>
    <!-- pObjName: name of instantiated object (optional) - required for external menu -->
    <xsl:param name="pObjName" select="''"/>
    <!-- pName: property name (required) -->
    <xsl:param name="pName" select="''"/>
    <!-- pValue: property value (required) -->
    <xsl:param name="pValue" select="''"/>
    <!-- Indent: parameter indent (optional, default ' ') -->
    <xsl:param name="Indent" select="' '"/>
    <!-- Inline: parameter separator (optional, default CR) -->
    <xsl:param name="Inline" select="$eol"/>
    <!-- pProp: property node (optional) - required for bitmap -->
    <xsl:param name="pProp" select="''"/>
    <!-- pNode: property node (optional) - required for complex type submode -->
    <xsl:param name="pNode" select="$config-objects-index/self::object[@name=$objName]/ancestor-or-self::*/properties/property[@name=$pName]"/>        

    <xsl:choose>
        <!-- skip empty node (not supported for product) -->
        <xsl:when test="not($pNode)"/>
        
        <!-- skip read-only properties -->
        <xsl:when test="($pNode/@read-only='true')"/>
        
        <!-- skip internal properties -->
        <xsl:when test="($pNode/@internal='true')"/>
        
        <!-- skip unpersisted properties in save config mode -->
        <xsl:when test="($pNode/@persisted='false')
                         and not($delta-config)"/>
                         
        <!-- skip if there's no value and no node -->
        <xsl:when test="(string($pValue)='') 
                         and (string($pProp)='')"/>
                         
        <!-- skip all default values except for vector properties and admin state -->
        <xsl:when test="($pNode/default=$pValue) 
                         and not($pNode/@vector='true') 
                         and not($pNode/@name='mAdminState')"/>
                         
        <!-- skip all default admin states except for singletons and intrinsics -->
        <xsl:when test="($pNode/@name='mAdminState')
                         and ($pNode/default=$pValue) 
                         and not($config-objects-index/self::object[@name=$objName]/@singleton='true')
                         and not($config-objects-index/self::object[@name=$objName]/@domain-singleton='true')
                         and not($config-objects-index/self::object[@name=$objName]/@intrinsic='true')"/>

		<!-- skip default admin-state for ethernet interfaces -->
		<xsl:when test="($pNode/@name='mAdminState')
                         and ($pNode/default=$pValue) 
                         and ($objName = 'EthernetInterface')"/>

        <!-- skip if it's got the special name "empty_*" (webgui form artifact) -->
        <xsl:when test="(starts-with($pName, 'empty_'))"/>
        
        <!-- value differs from default value -->
        <xsl:otherwise>
            <!-- if sub menu -->
            <xsl:if test="($objAlias!='')">
                <!-- enter menu -->
                <xsl:value-of select="concat($eol, $objAlias, ' ', $pObjName, $eol, '  ')"/>
            </xsl:if>

            <xsl:choose>
                <!-- test if cli alias is defined-->
                <xsl:when test="($pNode/cli-alias)">
                    <!-- set cli alias -->
                    <xsl:variable name="alias" select="$pNode/cli-alias"/>

                    <xsl:choose>
                        <!-- if it is a toggle -->
                        <xsl:when test="($pNode/@type='dmToggle')">
                            <xsl:choose>
                                <!-- if inline parameter or external submenu-->
                                <xsl:when test="($Inline='') or ($objAlias!='')">
                                    <!-- output in form '<alias> <value> [CR]' -->
                                    <xsl:value-of select="concat($Indent, $alias, ' ', dpfunc:esc($pValue), $Inline)"/>
                                </xsl:when>

                                <!-- if single command line -->
                                <xsl:otherwise>
                                    <xsl:choose>
                                        <!-- if toggle is off -->
                                        <xsl:when test="($pValue='off')">
                                            <!-- output in form 'no <alias> [objname]' -->
                                            <xsl:value-of select="concat($Indent, 'no ', $alias, ' ', $pObjName, $eol)"/>
                                        </xsl:when>
                                        <!-- if toggle is on -->
                                        <xsl:otherwise>
                                            <!-- output in form '<alias> [objname]' -->
                                            <xsl:value-of select="concat($Indent, $alias, ' ', $pObjName, $eol)"/>
                                        </xsl:otherwise>
                                    </xsl:choose>
                                </xsl:otherwise>
                            </xsl:choose>
                        </xsl:when>

                        <!-- if it is a string values -->
                        <xsl:when test="($pNode/@type='dmString' or $pNode/@type='dmURL' or $pNode/@type='dmXPathExpr' or $pNode/@type='dmTimeStamp')">
                            <!-- string values are in quotes -->
                            <xsl:value-of select="concat($Indent, $alias, ' ', dpfunc:quoesc($pValue), $Inline)"/>
                        </xsl:when>

                        <!-- for everything else, test base node -->
                        <xsl:otherwise>
                            <xsl:variable name="typeNode">
                                <xsl:call-template name="schema-find-type">
                                    <xsl:with-param name="typeName" select="$pNode/@type"/>
                                </xsl:call-template>
                            </xsl:variable>

                            <xsl:choose>
                                <!-- if it is a complex property -->
                                <xsl:when test="($typeNode/*[@base='complex'])">
                                    <xsl:variable name="current" select="." />
                                    <xsl:variable name="submode" select="not($typeNode/type/properties/property[not(cli-alias)])" />

                                    <xsl:value-of select="concat($Indent, $alias)"/>
                                    <xsl:choose>
                                        <!-- 
                                            cli complex submode was added in 3.7.1, enable when downgrade
                                            compatibility is reasonably assured
                                        -->
                                        <!-- <xsl:when test="$submode"> -->
                                        <xsl:when test="false()">
                                            <xsl:value-of select="concat($eol)"/>

                                            <!-- for each complex type property -->
                                            <xsl:for-each select="$typeNode/type/properties/property">
                                                <xsl:variable name="arg-node" select="$current/*[local-name() = current()/@name]" />
                                                <xsl:apply-templates mode="DefaultProperty" select="$arg-node">
                                                    <xsl:with-param name="objName" select="$objName"/>
                                                    <xsl:with-param name="pName" select="@name"/>
                                                    <xsl:with-param name="pValue" select="$arg-node"/>
                                                    <xsl:with-param name="pProp" select="$arg-node"/>
                                                    <xsl:with-param name="Indent" select="concat($Indent, '  ')"/>
                                                    <xsl:with-param name="pNode" select="."/>
                                                </xsl:apply-templates>
                                            </xsl:for-each>

                                            <xsl:value-of select="concat($Indent, 'exit', $eol)"/>
                                        </xsl:when>

                                        <xsl:otherwise>
                                            <!-- for each complex type property -->
                                            <xsl:for-each select="$typeNode/type/properties/property">
                                                <!-- find the drmgmt definition of this property to determine its type. -->
                                                <xsl:variable name="subPropName" select="@name"/>
                                                <xsl:variable name="subPropType" select="$type-index/self::type[@name = current()/@type]" />

                                                <xsl:variable name="arg-node" select="$current/*[local-name() = current()/@name]" />

                                                <xsl:choose>
                                                    <xsl:when test="string($subPropType/@base) = 'bitmap'">
                                                        <xsl:value-of select='concat(" ", dpfunc:quoesc(dpfunc:bitmap-to-string($arg-node)))' />
                                                    </xsl:when>
                                                    <xsl:when test="string($subPropType/@base) = 'enumeration' and string($arg-node) = ''">
                                                        <!-- hidden complex enumerations with no value specified can't be submitted as "" -->
                                                        <xsl:choose>
                                                            <!-- default value specified -->
                                                            <xsl:when test="$subPropType/value-list/value[@default]">
                                                                <xsl:value-of select='concat(" ", dpfunc:quoesc($subPropType/value-list/value[@default]/@name))'/>
                                                            </xsl:when>
                                                            <!-- otherwise (i.e. explicit), set to first element -->
                                                            <xsl:otherwise>
                                                                <xsl:value-of select='concat(" ", dpfunc:quoesc($subPropType/value-list/value[1]/@name))'/>
                                                            </xsl:otherwise>
                                                        </xsl:choose>
                                                    </xsl:when>
                                                    <xsl:when test="string($arg-node) = '' and string(default) != ''">
                                                        <!-- hidden complex toggles with no value specified can't be submitted as "" -->
                                                        <xsl:value-of select='concat(" ", dpfunc:quoesc(default))'/>
                                                    </xsl:when>
                                                    <xsl:otherwise>
                                                        <xsl:value-of select='concat(" ", dpfunc:quoesc($arg-node))'/>
                                                    </xsl:otherwise>
                                                </xsl:choose>
                                            </xsl:for-each>

                                            <xsl:value-of select="$eol"/>
                                        </xsl:otherwise>
                                    </xsl:choose>

                                </xsl:when>

                                <!-- if it is a bitmap -->
                                <xsl:when test="($typeNode/*[@base='bitmap'])">                        
                                    <xsl:value-of select="concat($Indent, $alias, ' ')"/>
                                    <xsl:value-of select="concat(dpfunc:quoesc(dpfunc:bitmap-to-string(.)), ' ')"/>
                                    <xsl:value-of select="concat($Inline)"/>
                                </xsl:when>                        

                                <xsl:otherwise>
                                    <!-- write cli output if not empty value -->
                                    <xsl:if test="not(string($pValue)='')">
                                        <xsl:value-of select="concat($Indent, $alias, ' ', dpfunc:esc($pValue), $Inline)"/>
                                    </xsl:if>
                                </xsl:otherwise>
                            </xsl:choose>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:when>

                <!-- no cli-alias defined -->
                <xsl:otherwise>
                    <xsl:message dp:type="mgmt" dp:priority="error">Missing cli-alias in '<xsl:value-of select="$objName"/>,<xsl:value-of select="$pName"/>'</xsl:message>                    
                    <xsl:value-of select="concat('# ', $Indent, $pName, ' ', dpfunc:esc($pValue))"/>                
                </xsl:otherwise>
            </xsl:choose>

            <!-- if sub menu -->
            <xsl:if test="($objAlias!='')">
                <!-- exit menu -->
                <xsl:value-of select="concat('exit', $eol)"/>
            </xsl:if>
        </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <!-- convert a null string to "" -->
  <xsl:template match="*" mode="NullableValue">
      <xsl:choose>
          <xsl:when test="string-length()=0">
            <xsl:value-of select="concat($quote, $quote)"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="dpfunc:quoesc(text())"/>
          </xsl:otherwise>
      </xsl:choose>
  </xsl:template>

  <!-- ### Actions ######################################################### -->

  <xsl:template match="args[action='FlushDocumentCache']" mode="cli-actions">
      <xsl:value-of select="concat(
                            'configure terminal', $eol, 
                            'documentcache ', XMLManager, $eol,
                            'clear *', $eol,
                            'exit', $eol)"/>
  </xsl:template>
  
  <xsl:template match="args[action='RefreshDocument']" mode="cli-actions">
      <xsl:value-of select="concat(
                            'configure terminal', $eol, 
                            'documentcache ', XMLManager, $eol,
                            'clear ',  dpfunc:quoesc(Document), $eol,
                            'exit', $eol)"/>
  </xsl:template>

  <xsl:template match="args[action='CacheWSDL']" mode="cli-actions">
      <xsl:value-of select="concat(
                            'configure terminal', $eol, 
                            'no stylesheet ', XMLManager, ' ', dpfunc:quoesc(URL), $eol,
                            'cache wsdl ', XMLManager, ' ', dpfunc:quoesc(URL), $eol)"/>
  </xsl:template>


  <xsl:template match="args[action='PacketCapture']" mode="cli-actions">
      <xsl:value-of select="concat(
                            'configure terminal', $eol, 
                            'interface ', Interface, $eol,
                            'packet-capture temporary:///capture.pcap 30 10000', $eol)"/>
  </xsl:template>

  <xsl:template match="args[action='StopPacketCapture']" mode="cli-actions">
      <xsl:value-of select="concat(
                            'configure terminal', $eol, 
                            'interface ', Interface, $eol,
                            'no packet-capture temporary:///capture.pcap', $eol)"/>
  </xsl:template>

  <xsl:template match="args[action='VLANPacketCapture']" mode="cli-actions">
      <xsl:value-of select="concat(
                            'configure terminal', $eol, 
                            'vlan-sub-interface ', Interface, $eol,
                            'packet-capture temporary:///capture.pcap 30 10000', $eol,
                            'exit', $eol)"/>
  </xsl:template>

  <xsl:template match="args[action='VLANStopPacketCapture']" mode="cli-actions">
      <xsl:value-of select="concat(
                            'configure terminal', $eol, 
                            'vlan-sub-interface ', Interface, $eol,
                            'no packet-capture temporary:///capture.pcap', $eol,
                            'exit', $eol)"/>
  </xsl:template>

  <xsl:template match="args[action='PacketCaptureDebug']" mode="cli-actions">
      <xsl:value-of select="concat(
                            'configure terminal', $eol, 
                            'interface ', Interface, $eol,
                            'packet-capture temporary:///capture.pcap ')"/>                            
      <xsl:choose>
          <xsl:when test="CaptureMode = 'continuous'">
              <xsl:text>-1</xsl:text>
          </xsl:when>
          <xsl:otherwise>
              <xsl:value-of select="MaxTime"/>
          </xsl:otherwise>
      </xsl:choose>      
      <xsl:value-of select="concat(' ', MaxSize, $eol)"/>
  </xsl:template>

  <xsl:template match="args[action='UniversalPacketCaptureDebug']" mode="cli-actions">
      <xsl:value-of select="concat(
                            'configure terminal', $eol)"/>
      <xsl:choose>
          <xsl:when test="InterfaceType = 'VLAN'">
      <xsl:value-of select="concat(
                                    'vlan-sub-interface ', VLANInterface, $eol)"/>
          </xsl:when>
          <xsl:when test="InterfaceType = 'Ethernet'">
      <xsl:value-of select="concat(
                                    'interface ', EthernetInterface, $eol)"/>
          </xsl:when>
      </xsl:choose>
      <xsl:value-of select="concat(
                            'packet-capture temporary:///capture.pcap ')"/>                            
      <xsl:choose>
          <xsl:when test="CaptureMode = 'continuous'">
              <xsl:text>-1</xsl:text>
          </xsl:when>
          <xsl:otherwise>
              <xsl:value-of select="MaxTime"/>
          </xsl:otherwise>
      </xsl:choose>      
      <xsl:value-of select="concat(' ', MaxSize, $eol, 'exit', $eol)"/>
  </xsl:template>

  <xsl:template match="args[action='UniversalStopPacketCapture']" mode="cli-actions">
      <xsl:value-of select="concat(
                            'configure terminal', $eol)"/>
      <xsl:choose>
          <xsl:when test="InterfaceType = 'VLAN'">
              <xsl:value-of select="concat(
                                    'vlan-sub-interface ', VLANInterface, $eol)"/>
          </xsl:when>
          <xsl:when test="InterfaceType = 'Ethernet'">
              <xsl:value-of select="concat(
                                    'interface ', EthernetInterface, $eol)"/>
          </xsl:when>
      </xsl:choose>
      <xsl:value-of select="concat(
                            'no packet-capture temporary:///capture.pcap', $eol,
                            'exit', $eol)"/>
  </xsl:template>

  <xsl:template match="args[action='DeleteHSMKey']" mode="cli-actions">
      <xsl:value-of select="concat(
                            'configure terminal', $eol, 
                            'crypto', $eol, 
                            'hsm-delete-key 0x', KeyHandle, $eol)"/>
  </xsl:template>

  <xsl:template match="args[action='CryptoImport']" mode="cli-actions">
      <xsl:variable name="passwdArgs">
        <xsl:choose>
          <xsl:when test="string(ImportPassword)">
            <xsl:value-of select="concat('password ', ImportPassword, ' ')"/>
          </xsl:when>
          <xsl:when test="string(ImportPasswordAlias)">
            <xsl:value-of select="concat('password-alias ', ImportPasswordAlias, ' ')"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="''"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:variable>

      <xsl:variable name="exportableArgs">
        <xsl:choose>
          <xsl:when test="string(KwkExportable) = 'on'">
            <xsl:value-of select="'exportable hsmkwk '"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="''"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:variable>

      <xsl:value-of select="concat('configure terminal', $eol, 
                                   'crypto', $eol, 
                                   'crypto-import ',
                                   ObjectType, ' ', ObjectName, ' ',
                                   'input ', InputFilename, ' ',
                                   $exportableArgs,
                                   $passwdArgs, $eol)"/>
  </xsl:template>

  <xsl:template match="args[action='CryptoExport']" mode="cli-actions">
      <xsl:variable name="mechanismargs">
        <xsl:choose>
          <xsl:when test="string(Mechanism) and ObjectType='key'">
            <xsl:value-of select="concat('mechanism ', Mechanism, ' ')"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="''"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:variable>

      <xsl:value-of select="concat('configure terminal', $eol, 
                                   'crypto', $eol, 
                                   'crypto-export ',
                                   ObjectType, ' ', ObjectName, ' ',
                                   'output temporary:///', OutputFilename, ' ',
                                   $mechanismargs, $eol)"/>
  </xsl:template>

  <xsl:template match="args[action='HSMCloneKWK']" mode="cli-actions">
      <xsl:variable name="inputargs">
        <xsl:choose>
          <xsl:when test="string(InputFilename)">
            <xsl:value-of select="concat('input ', InputFilename, ' ')"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="''"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:variable>

      <xsl:variable name="outputargs">
        <xsl:choose>
          <xsl:when test="string(OutputFilename)">
            <xsl:value-of select="concat('output temporary:///', OutputFilename, ' ')"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="''"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:variable>

      <xsl:value-of select="concat('configure terminal', $eol, 
                                   'crypto', $eol, 
                                   'hsm-clone-kwk ',
                                   $inputargs,
                                   $outputargs,
                                   $eol)"/>
  </xsl:template>

  <xsl:template match="args[action='ApplyPatch']" mode="cli-actions">
      <!-- this command expects a bare filename here -->
      <xsl:variable name="bare-file">
          <xsl:choose>
              <xsl:when test="starts-with(File, 'image:///')">
                  <xsl:value-of select="substring-after(File, 'image:///')"/>
              </xsl:when>
              <xsl:otherwise>
                  <xsl:value-of select="File"/>                  
              </xsl:otherwise>
          </xsl:choose>
      </xsl:variable>
      <xsl:value-of select="concat(
                            'configure terminal', $eol,
                            'flash', $eol,
                            'boot image ', dpfunc:quoesc($bare-file), $eol,
                            'exit', $eol, 'exit', $eol)"/>
  </xsl:template>

  <xsl:template mode="cli-error-processing"
      match="response[../args/screen='action' and ../args/action='ApplyPatch']">
      <response>
          <xsl:choose>
              <xsl:when test="result='ERROR'">
                  <result>ERROR</result>
                  <details>
                      <xsl:text>Could not install firmware image.</xsl:text>
                      <br/>
                      <xsl:value-of select="details"/>                                                    
                      <br/>
                      <xsl:text> The system will not reboot.</xsl:text>                                                    
                  </details>
              </xsl:when>
              <xsl:otherwise>
                  <result>OK</result>
                  <details>
                      <xsl:text>Successfully installed firmware image.</xsl:text>
                      <xsl:text> The system will reboot now.</xsl:text>                                                    
                  </details>
                  <xsl:copy-of select="pending" />
              </xsl:otherwise>
          </xsl:choose>
      </response>
  </xsl:template>

 <xsl:template match="args[action='BootSwitch']" mode="cli-actions">
      <!-- this command expects a bare filename here -->
      <xsl:value-of select="concat(
                            'configure terminal', $eol,
                            'flash', $eol,
                            'boot switch', $eol,
                            'exit', $eol, 'exit', $eol)"/>
  </xsl:template>

  <xsl:template mode="cli-error-processing"
      match="response[../args/screen='action' and ../args/action='BootSwitch']">
      <response>
          <xsl:choose>
              <xsl:when test="result='ERROR'">
                  <result>ERROR</result>
                  <details>
                      <xsl:text>Failed to roll-back firmware.</xsl:text>
                  </details>
              </xsl:when>
              <xsl:otherwise>
                  <result>OK</result>
                  <details>
                      <xsl:text>Firmware roll-back successful.</xsl:text>
                  </details>
              </xsl:otherwise>
          </xsl:choose>
      </response>
  </xsl:template>

  <xsl:template match="args[action='SelectConfig']" mode="cli-actions">
      <!-- this command expects a bare filename here -->
      <xsl:variable name="bare-file">
          <xsl:choose>
              <xsl:when test="starts-with(File, 'config:///')">
                  <xsl:value-of select="substring-after(File, 'config:///')"/>
              </xsl:when>
              <xsl:otherwise>
                  <xsl:value-of select="File"/>                  
              </xsl:otherwise>
          </xsl:choose>
      </xsl:variable>
      <xsl:value-of select="concat(
                            'configure terminal', $eol,
                            'flash', $eol,
                            'boot config ', dpfunc:quoesc($bare-file), $eol,
                            'exit', $eol, 'exit', $eol)"/>
  </xsl:template>

  <xsl:template match="args[action='UndoConfig']" mode="cli-actions">
      <xsl:variable name="type" select="Class"/>
      <xsl:variable name="alias" select="$config-objects-index/self::object[@name=$type]/cli-alias"/>   
      <xsl:variable name="uri" select="$config-objects-index/self::object[@name=$type]/uri"/>   
      
      <xsl:value-of select="concat('configure terminal', $eol)"/>
      <xsl:if test="starts-with($uri, 'crypto')">
          <xsl:value-of select="concat('crypto', $eol)"/>
      </xsl:if>
      <xsl:value-of select="concat('undo ', dpfunc:quoesc($alias), ' ', dpfunc:quoesc(Name), $eol)"/>
  </xsl:template>

  <xsl:template match="args[action='FetchFile']" mode="cli-actions">
      <xsl:value-of select="concat('configure terminal', $eol, 'copy ')"/>
      <xsl:if test="Overwrite = 'on'">
          <xsl:text>-f</xsl:text>
      </xsl:if>
      <xsl:value-of select="concat(' ', dpfunc:quoesc(URL), ' ', dpfunc:quoesc(File), $eol)"/>
  </xsl:template>

  <xsl:template match="args[action='MoveFile']" mode="cli-actions">
      <xsl:value-of select="concat('configure terminal', $eol, 'move ')"/>
      <xsl:if test="Overwrite = 'on'">
          <xsl:text>-f</xsl:text>
      </xsl:if>
      <xsl:value-of select="concat(' ', dpfunc:quoesc(sURL), ' ', dpfunc:quoesc(dURL), $eol)"/>
  </xsl:template>

  <xsl:template match="args[action='Shutdown']" mode="cli-actions">
      <xsl:value-of select="concat(
                            'configure terminal', $eol,
                            'flash', $eol,
                            'shutdown ', Mode, ' ', Delay, $eol,
                            'exit', $eol, 'exit', $eol)"/>
  </xsl:template>

  <xsl:template match="args[action='CreateTAMFiles']" mode="cli-actions">
      <xsl:variable name="actionNode" select="$schema/action-objects/action[@name='CreateTAMFiles']"/>
      <xsl:value-of select="concat(
                            'configure terminal', $eol,
                            'create-tam-files ')"/>

      <xsl:apply-templates mode="create-tam-files-params">
          <xsl:with-param name="paramsNode" select="$actionNode/parameters"/>
      </xsl:apply-templates>

      <xsl:value-of select="$eol"/>
  </xsl:template>

  <xsl:template mode="create-tam-files-params" match="*">
      <xsl:param name="paramsNode"/>

     <xsl:variable name="name" select="local-name(.)"/>
     <xsl:variable name="node" select="$paramsNode/parameter[@name=$name]"/>

      <xsl:if test="string(text()) and string($node/cli-alias)">
              <xsl:value-of select="concat(' ', $node/cli-alias, ' ', dpfunc:quoesc(text()))"/>
      </xsl:if>
  </xsl:template>

  <xsl:template match="args[action='Keygen']" mode="cli-actions">  
      <xsl:variable name="pNode" select="$schema/action-objects/action[@name='Keygen']"/>
        
      <xsl:value-of select="concat(
                            'configure terminal', $eol,
                            'crypto', $eol,
                            'keygen')"/>

      <xsl:variable name="order">
          <xsl:choose>
              <xsl:when test="LDAPOrder='on'">
                  <xsl:value-of select="'descending'"/>
              </xsl:when>
              <xsl:otherwise>
                  <xsl:value-of select="'ascending'"/>
              </xsl:otherwise>              
          </xsl:choose>
      </xsl:variable>
      
      <xsl:apply-templates mode="keygen-param" select="*[local-name()=$pNode//parameter/@name]">
          <xsl:sort select="position()" data-type="number" order="{$order}"/>
          <xsl:with-param name="typeNode" select="$pNode"/>
      </xsl:apply-templates>
      
      <xsl:value-of select="$eol"/>
  </xsl:template>

  <!-- suppress directional parameter -->
  <xsl:template mode="keygen-param" match="LDAPOrder"/>
  
  <!-- express command line parameter -->
  <xsl:template mode="keygen-param" match="*">
      <xsl:param name="typeNode"/>
      
      <xsl:variable name="paramName" select="local-name(.)"/>
      <xsl:variable name="paramNode" select="$typeNode//parameter[@name=$paramName]"/>      
      
      <xsl:choose>
          <xsl:when test="($paramNode/@type='dmToggle') and (text()='off')"/>
          <xsl:when test="($paramNode/@type='dmToggle') and (text()='on')">
              <xsl:value-of select="concat(' ', $paramNode/cli-alias)"/>
          </xsl:when>
          <xsl:when test="text() and not(text()='')">
              <xsl:value-of select="concat(' ', $paramNode/cli-alias, ' ', dpfunc:quoesc(text()))"/>
          </xsl:when>
      </xsl:choose>
  </xsl:template>

  <!-- This template is a big, horrendous kludge.
       It duplicates firmware behaviour of the keygen command,
       and will get out of sync (again) the next time that command changes. -->
  <xsl:template mode="cli-error-processing"
      match="response[../args/screen='action' and ../args/action='Keygen']">
      
      <response>
          <xsl:choose>
              <xsl:when test="result='ERROR'">
                <!-- Return the error information which the keygen command put in the log -->
                <result>ERROR</result>
                <xsl:copy-of select="script-log"/>
              </xsl:when>
              <xsl:otherwise>
                  <result>OK</result>
                  <details>
                      <xsl:variable name="objName">
                          <xsl:choose>
                              <xsl:when test="../args/ObjectName and not (../args/ObjectName='')">
                                  <xsl:value-of select="../args/ObjectName"/>
                              </xsl:when>
                              <xsl:when test="../args/CN and not (../args/CN='')">
                                  <xsl:value-of select="../args/CN"/>
                              </xsl:when>
                              <xsl:otherwise>
                                  <xsl:text></xsl:text>
                              </xsl:otherwise>
                          </xsl:choose>
                      </xsl:variable>

                      <xsl:variable name="outPrefix">
                          <xsl:choose>
                              <xsl:when test="../args/FileName and not (../args/FileName='')">
                                  <xsl:value-of select="../args/FileName"/>
                              </xsl:when>
                              <xsl:otherwise>
                                  <xsl:value-of select="$objName"/>
                              </xsl:otherwise>
                          </xsl:choose>
                      </xsl:variable>

                      <!-- output regarding the private key -->
                      <xsl:choose>
                          <xsl:when test="../args/UsingKey and not (../args/UsingKey='')">
                              <xsl:text>Reused existing private key "</xsl:text>
                              <xsl:value-of select="../args/UsingKey"/>
                              <xsl:text>"</xsl:text>
                          </xsl:when>
                          <xsl:otherwise>
                              <xsl:choose>
                                  <xsl:when test="../args/HSM='on'">
                                      <xsl:text>Generated private key on the HSM</xsl:text>
                                  </xsl:when>
                                  <xsl:otherwise>
                                      <xsl:text>Generated private key in "cert:</xsl:text>
                                      <xsl:value-of select="$outPrefix"/>
                                      <xsl:text>-privkey.pem"</xsl:text>
                                  </xsl:otherwise>
                              </xsl:choose>
                              <xsl:if test="../args/ExportKey='on'">
                                  <xsl:text> and exported a copy in "temporary:</xsl:text>
                                  <xsl:value-of select="$outPrefix"/>
                                  <xsl:text>-privkey.pem"</xsl:text>
                              </xsl:if>
                          </xsl:otherwise>
                      </xsl:choose>
                      <xsl:text>, </xsl:text>

                      <!-- output regarding the CSR -->
                      <xsl:text>Generated Certificate Signing Request in "temporary:</xsl:text>                      
                      <xsl:value-of select="$outPrefix"/>
                      <xsl:text>.csr"</xsl:text>
                      <xsl:text>, </xsl:text>

                      <!-- output regarding the sscert -->
                      <xsl:if test="../args/GenSSCert='on'">
                          <xsl:text>Generated Self-Signed Certificate in "cert:</xsl:text>
                          <xsl:value-of select="$outPrefix"/>
                          <xsl:text>-sscert.pem"</xsl:text>
                          <xsl:if test="../args/ExportSSCert='on'">
                              <xsl:text> and exported a copy in "temporary:</xsl:text>
                              <xsl:value-of select="$outPrefix"/>
                              <xsl:text>-sscert.pem"</xsl:text>
                          </xsl:if>
                          <xsl:text>, </xsl:text>
                      </xsl:if>

                      <!-- output regarding generated objects -->
                      <xsl:if test="../args/GenObject='on'">
                          <xsl:text>Generated a Crypto Key object named "</xsl:text>
                          <xsl:value-of select="$objName"/>
                          <xsl:text>"</xsl:text>
                          <xsl:if test="../args/GenSSCert='on'">
                              <xsl:text> and a Crypto Certificate object named "</xsl:text>
                              <xsl:value-of select="$objName"/>
                              <xsl:text>"</xsl:text>
                          </xsl:if>
                      </xsl:if>
                  </details>
              </xsl:otherwise>
          </xsl:choose>
      </response>
  </xsl:template>
  
  <xsl:template match="args[action='SetTimeAndDate']" mode="cli-actions">
      <xsl:if test="(Date != '')">
          <xsl:value-of select="concat($eol, 'clock ', Date, $eol)"/>
      </xsl:if>
      <xsl:if test="(Time != '')">
          <xsl:value-of select="concat('clock ', Time, $eol)"/>
      </xsl:if>
          
  </xsl:template>

  <xsl:template mode="cli-error-processing"
      match="response[../args/screen='action' and ../args/action='SetTimeAndDate']">
      <response>
          <xsl:choose>
              <xsl:when test="result='ERROR'">
                  <result>ERROR</result>
                  <details>Could not set system time and date.</details>
              </xsl:when>
              <xsl:otherwise>
                  <result>OK</result>
                  <details>Successfully updated system time and date</details>
              </xsl:otherwise>
          </xsl:choose>
      </response>
  </xsl:template>

  <xsl:template match="args[action='Disconnect']" mode="cli-actions">
      <xsl:value-of select="concat( 'configure terminal', $eol,
                                    'disconnect ', id, $eol)"/>
  </xsl:template>

  <xsl:template mode="cli-error-processing"
      match="response[../args/screen='action' and ../args/action='Ping']">     
      <response>
          <xsl:choose>
              <xsl:when test="result='ERROR'">
                  <xsl:choose>
                      <xsl:when test="starts-with(script-log/log//log-entry/message, 'Packets dropped')">
                          <result>ERROR</result>
                          <details>
                              <xsl:text>Ping packets dropped to remote host "</xsl:text>
                              <xsl:value-of select="../args/RemoteHost"/>
                              <xsl:text>". Please check system log or use
                              the CLI command for more details.</xsl:text>
                          </details>
                      </xsl:when>
                      <xsl:when test="starts-with(script-log/log//log-entry/message, 'Failed to resolve')">
                          <result>ERROR</result>
                          <details>
                              <xsl:text>Ping failed to resolve remote host "</xsl:text>
                              <xsl:value-of select="../args/RemoteHost"/>
                              <xsl:text>". Please check system log or use
                              the CLI command for more details.</xsl:text>
                          </details>
                      </xsl:when>
                      <xsl:when test="starts-with(script-log/log//log-entry/message, 'Host unreachable')">
                          <result>ERROR</result>
                          <details>
                              <xsl:text>Ping failed unreachable remote host "</xsl:text>
                              <xsl:value-of select="../args/RemoteHost"/>
                              <xsl:text>". Please check system log or use
                              the CLI command for more details.</xsl:text>
                          </details>
                      </xsl:when>
                      <xsl:otherwise>
                          <result>ERROR</result>
                          <details>
                              <xsl:text>Could not ping remote host "</xsl:text>
                              <xsl:value-of select="../args/RemoteHost"/>
                              <xsl:text>". Please check system log.</xsl:text>
                          </details>
                      </xsl:otherwise>
                  </xsl:choose>
              </xsl:when>
              <xsl:otherwise>
                  <result>OK</result>
                  <details>
                      <xsl:text>Successful ping to remote host "</xsl:text>
                      <xsl:value-of select="../args/RemoteHost"/>
                      <xsl:text>".</xsl:text>
                  </details>
              </xsl:otherwise>
          </xsl:choose>
      </response>
  </xsl:template>

  <xsl:template mode="cli-error-processing"
      match="response[../args/screen='action' and ../args/action='TCPConnectionTest']">
      <response>
          <xsl:choose>
              <xsl:when test="result='ERROR'">
                  <result>ERROR</result>
                  <xsl:choose>
                      <xsl:when test="contains(script-log/log//log-entry/message, 'connection refused')">
                          <details>
                              <xsl:text>TCP connection failed (connection refused)</xsl:text>
                          </details>
                      </xsl:when>
                      <xsl:when test="contains(script-log/log//log-entry/message, 'dns lookup failed')">
                          <details>
                              <xsl:text>TCP connection failed (dns lookup failed)</xsl:text>
                          </details>
                      </xsl:when>
                      <xsl:when test="contains(script-log/log//log-entry/message, 'connection timeout')">
                          <details>
                              <xsl:text>TCP connection failed (connection timeout)</xsl:text>
                          </details>
                      </xsl:when>
                      <xsl:otherwise>
                          <details>
                              <xsl:text>TCP connection failed</xsl:text>
                          </details>
                      </xsl:otherwise>
                  </xsl:choose>
              </xsl:when>
              <xsl:otherwise>
                  <result>OK</result>
                  <details>
                      <xsl:text>TCP connection successful</xsl:text>
                  </details>
              </xsl:otherwise>
          </xsl:choose>
      </response>
  </xsl:template>

  <xsl:template match="args[action='ChangePassword']" mode="cli-actions">
     <xsl:value-of select="concat('configure terminal', $eol,
                            'user-password ', dpfunc:quoesc(Password), ' ', dpfunc:quoesc(OldPassword), $eol)"/>
  </xsl:template>

  <xsl:template mode="cli-error-processing"
      match="response[../args/screen='action' and ../args/action='ChangePassword']">
      
      <response>
          <xsl:choose>
              <xsl:when test="result='ERROR'">
                  <result>ERROR</result>
                  <details>
                      <xsl:text>Could not change password.</xsl:text>
                  </details>
              </xsl:when>
              <xsl:otherwise>
                  <result>OK</result>
                  <details>
                      <xsl:text>Successfully changed password.</xsl:text>
                  </details>
              </xsl:otherwise>
          </xsl:choose>
      </response>
  </xsl:template>
  
  <xsl:template match="args[action='SetRBMDebugLog']" mode="cli-actions">  
      <xsl:value-of select="concat('configure terminal', $eol)"/>
      
      <xsl:variable name="log-config">
        <xsl:call-template name="do-mgmt-request">
            <xsl:with-param name="session">
                <xsl:choose>
                    <xsl:when test="../args/session"><xsl:value-of select="../args/session"/></xsl:when>
                    <xsl:otherwise><xsl:value-of select="$sessionid"/></xsl:otherwise>
                </xsl:choose>
            </xsl:with-param>
            <xsl:with-param name="request">
                <request>
                  <operation type="get-config">
                    <request-class>LogTarget</request-class>
                    <request-name>default-log</request-name>                                  
                  </operation>
                </request>
            </xsl:with-param>
        </xsl:call-template>
      </xsl:variable>
      
      <xsl:choose>
          <xsl:when test="string(RBMLog) = 'on'">
              <xsl:value-of select="concat('set-system-var var://system/map/debug 3', $eol)"/>              
              <xsl:value-of select="concat('logging event default-log rbm debug', $eol)"/>              
          </xsl:when>
          
          <xsl:otherwise>
              <xsl:value-of select="concat('set-system-var var://system/map/debug 0', $eol)"/>              
              <xsl:if test="$log-config/response/operation[@type='get-config']
                            /configuration/*[(local-name()='LogTarget') and (@name='default-log')]
                            /LogEvents[Class='rbm']">
                  <xsl:value-of select="concat('no logging event default-log rbm', $eol)"/>              
              </xsl:if>
          </xsl:otherwise>
      </xsl:choose>
  </xsl:template>

  <xsl:template match="args[action='SetLogLevel']" mode="cli-actions">
      <xsl:value-of select="concat('configure terminal', $eol,
                                   'loglevel ', LogLevel, $eol)"/>
          
              <xsl:variable name="log-config">
                <xsl:call-template name="do-mgmt-request">
                    <xsl:with-param name="session">
                        <xsl:choose>
                    <xsl:when test="../args/session"><xsl:value-of select="../args/session"/></xsl:when>
                    <xsl:otherwise><xsl:value-of select="$sessionid"/></xsl:otherwise>
                        </xsl:choose>
                    </xsl:with-param>
                    <xsl:with-param name="request">
                        <request>
                          <operation type="get-config">
                            <request-class>LogTarget</request-class>
                            <request-name>default-log</request-name>                                  
                          </operation>
                        </request>
                    </xsl:with-param>
                </xsl:call-template>
              </xsl:variable>
              
      <xsl:if test="InternalLog">
          <xsl:choose>                             
              <xsl:when test="string(InternalLog) = 'on'">                             
                  <xsl:value-of select="concat('logging event default-log webgui ', LogLevel, $eol)"/>
              </xsl:when>
              
              <xsl:otherwise>              
              <xsl:if test="$log-config/response/operation[@type='get-config'] 
                              /configuration/*[(local-name()='LogTarget') and (@name='default-log')]
                              /LogEvents[Class='webgui']">
                  <xsl:value-of select="concat('no logging event default-log webgui', $eol)"/>
              </xsl:if>              
          </xsl:otherwise>          
      </xsl:choose>
      </xsl:if>
      
      <xsl:if test="RBMLog">
          <xsl:choose>
              <xsl:when test="string(RBMLog) = 'on'">
                  <xsl:value-of select="concat('set-system-var var://system/map/debug 3', $eol)"/>              
                  <xsl:value-of select="concat('logging event default-log rbm debug', $eol)"/>              
              </xsl:when>
              
              <xsl:otherwise>
                  <xsl:value-of select="concat('set-system-var var://system/map/debug 0', $eol)"/>              
                  <xsl:if test="$log-config/response/operation[@type='get-config']
                                /configuration/*[(local-name()='LogTarget') and (@name='default-log')]
                                /LogEvents[Class='rbm']">
                      <xsl:value-of select="concat('no logging event default-log rbm', $eol)"/>              
                  </xsl:if>
              </xsl:otherwise>
          </xsl:choose>
      </xsl:if>
  </xsl:template>

  <xsl:template mode="cli-error-processing"
      match="response[../args/screen='action' and ../args/action='SetLogLevel']">
      <response>
          <xsl:choose>
              <xsl:when test="result='ERROR'">
                  <result>ERROR</result>
                  <details>Could not set system log level.</details>
              </xsl:when>
              <xsl:otherwise>
                  <result>OK</result>
                  <details>Successfully set system log level.</details>
              </xsl:otherwise>
          </xsl:choose>
      </response>
  </xsl:template>

  <xsl:template match="args[action='ErrorReport']" mode="cli-actions">
      <xsl:value-of select="concat('configure terminal', $eol)"/>
      <xsl:if test="string(InternalState) = 'on'">
          <xsl:value-of select="concat('save internal-state', $eol)"/>
      </xsl:if>
      <xsl:value-of select="concat('save error-report', $eol)"/>
      <xsl:if test="string(InternalState) = 'on'">
          <xsl:value-of select="concat('delete temporary:///internal-state.txt', $eol)"/>
      </xsl:if>
  </xsl:template>

  <xsl:template mode="cli-error-processing"
      match="response[../args/screen='action' and ../args/action='ErrorReport']">
      <response>      
          <xsl:choose>
              <xsl:when test="result='ERROR'">
                  <result>ERROR</result>
                  <details>Could not generate error-report.</details>
              </xsl:when>
              <xsl:otherwise>
                  <result>OK</result>
                  <details>Successfully generated error-report in temporary:///error-report.txt.</details>
              </xsl:otherwise>
          </xsl:choose>
      </response>
  </xsl:template>

  <xsl:template match="args[action='SendErrorReport']" mode="cli-actions">
    <xsl:value-of select="concat('configure terminal', $eol, 
                                 'send error-report', 
                                 ' ', SmtpServer,
                                 ' ', dpfunc:quoesc(LocationIdentifier),
                                 ' ', EmailAddress, $eol)"/>
  </xsl:template>

  <xsl:template mode="cli-error-processing"
      match="response[../args/screen='action' and ../args/action='SendErrorReport']">

      <response>      
          <xsl:choose>
              <xsl:when test="result='ERROR'">
                  <result>ERROR</result>
                  <details>Could not sent error-report.</details>
              </xsl:when>
              <xsl:otherwise>
                  <result>OK</result>
                  <details>Successfully sent error-report.</details>
              </xsl:otherwise>
          </xsl:choose>
      </response>
  </xsl:template>

  <xsl:template mode="cli-error-processing"
      match="response[../args/screen='action' and ../args/action='TestURLRewrite']">
      <response>
          <xsl:choose>
              <xsl:when test="script-log/log//log-entry/code='0x81000076' or
                              script-log/log//log-entry/code='0x81000077'">
                          <result>OK</result>
                          <details>
                              <xsl:for-each select="script-log/log//log-entry">
                                  <xsl:if test="not(starts-with(message, '=== Line'))">
                                      <xsl:value-of select="message"/>
                                      <br/>
                                  </xsl:if>
                              </xsl:for-each>
                          </details>                          
                      </xsl:when>
                      <xsl:otherwise>
                          <result>ERROR</result>
                          <details>The URL did not match the URL Rewrite Policy.</details>
                      </xsl:otherwise>
                  </xsl:choose>
      </response>
  </xsl:template>

  <xsl:template mode="cli-error-processing"
      match="response[../args/screen='action' and ../args/action='TestURLRefresh']">
      <response>
          <xsl:choose>
              <xsl:when test="script-log/log//log-entry/code='0x81000078' or
                              script-log/log//log-entry/code='0x81000079'">
                          <result>OK</result>
                          <details>
                              <xsl:for-each select="script-log/log//log-entry">
                                  <xsl:if test="not(starts-with(message, '=== Line'))">
                                      <xsl:value-of select="message"/>
                                      <br/>
                                  </xsl:if>
                              </xsl:for-each>
                          </details>                          
                      </xsl:when>
                      <xsl:otherwise>
                          <result>ERROR</result>
                          <details>The URL did not match the URL Refresh Policy.</details>
                      </xsl:otherwise>
                  </xsl:choose>
      </response>
  </xsl:template>
  
  <xsl:template mode="cli-error-processing"
      match="response[../args/screen='action' and ../args/action='TestURLMap']">
      <response>
          <xsl:choose>
              <xsl:when test="result='ERROR'">
                  <result>ERROR</result>
                  <details>The URL did not match the URL Map.</details>
              </xsl:when>
              <xsl:otherwise>
                  <result>OK</result>
                  <details>The URL did match the URL Map.</details>
              </xsl:otherwise>
          </xsl:choose>
      </response>
  </xsl:template>
  
  <xsl:template mode="cli-error-processing"
      match="response[../args/screen='action' and ../args/action='TestRadius']">
      <response>
          <xsl:choose>
              <xsl:when test="result='ERROR'">
                  <result>ERROR</result>
                  <details>The user was not authenticated.</details>
              </xsl:when>
              <xsl:otherwise>
                  <result>OK</result>
                  <details>The user was authenticated successfully.</details>
              </xsl:otherwise>
          </xsl:choose>
      </response>
  </xsl:template>
  
  <xsl:template match="args[action='DeviceCertificate']" mode="cli-actions">
      <xsl:value-of select="concat(
                            'configure terminal', $eol, 
                            'crypto', $eol,
                            'keygen CN ', dpfunc:quoesc(CN), ' rsa 1024 export-sscert file-name device-id ')"/>
      <!-- negative test to catch if the implied default 'on' is changed -->
      <xsl:if test="string(SSCert) != 'off'">
          <xsl:value-of select="concat(
                                'gen-sscert', $eol,
                                'key device-id cert:///device-id-privkey.pem', $eol,
                                'certificate device-id cert:///device-id-sscert.pem', $eol,
                                'idcred device-id device-id device-id', $eol,
                                'profile device-id device-id', $eol,
                                'exit', $eol,
                                'sslproxy device-id reverse device-id', $eol)"/>
      </xsl:if>      
      <xsl:value-of select="$eol"/>      
  </xsl:template>

  <xsl:template mode="cli-error-processing"
      match="response[../args/screen='action' and ../args/action='DeviceCertificate']">
      <response>
          <xsl:choose>
              <xsl:when test="result='ERROR'">
                  <result>ERROR</result>
                  <details>Creating the SSL Proxy Profile 'device-id' failed.</details>
              </xsl:when>
              <xsl:otherwise>
                  <result>OK</result>
                  <details>
                      <xsl:text>The SSL Proxy Profile 'device-id' has been created. </xsl:text> 
                      <xsl:text>Please update the page by selecting Refresh in your browser.</xsl:text>
                  </details>
              </xsl:otherwise>
          </xsl:choose>
      </response>
  </xsl:template>
  
  <!-- LocateDevice Action -->
  <xsl:template match="args[action='LocateDevice']" mode="cli-actions">
      <xsl:choose>
        <xsl:when test="string(LocateLED) != 'off'">
          <xsl:value-of select="concat('configure terminal', $eol,
                                       'locate-device on', $eol)"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="concat('configure terminal', $eol,
                                       'locate-device off', $eol)"/>
        </xsl:otherwise>
      </xsl:choose>
  </xsl:template>
  <xsl:template mode="cli-error-processing"
      match="response[../args/screen='action' and ../args/action='LocateDevice']">
      <response>
          <xsl:choose>
              <xsl:when test="result='ERROR'">
                  <result>ERROR</result>
                  <details>Locate LED operation change failed.</details>
              </xsl:when>
              <xsl:otherwise>
                  <result>OK</result>
                  <details>
                      <xsl:text>Locate LED operation change successful.</xsl:text>
                  </details>
              </xsl:otherwise>
          </xsl:choose>
      </response>
  </xsl:template>
  
  <!-- this cli-error-processor deals with various delete issues -->
  <xsl:template mode="cli-error-processing" 
    match="response[  (../args/action='delete') and (result='ERROR')]">
    
    <xsl:choose>
        <xsl:when test="details!=''">
            <response>
                <result>ERROR</result>
                <details><xsl:value-of select="details"/></details>
            </response>
        </xsl:when>
        <xsl:when test="script-log/log//log-entry/code='0x00330007'">
            <!-- suppress ie duplicate delete -->
            <response>
                <result>OK</result>
            </response>
        </xsl:when>
        <xsl:when test="script-log/log//log-entry/code='0x81000013'">
            <response>
                <result>ERROR</result>
                <details code="0x81000013"><xsl:value-of select="script-log/log//log-entry[code='0x81000013']/message"/></details>
            </response>
        </xsl:when>
        <xsl:when test="script-log/log//log-entry/code='0x00330008'">
            <response>
                <result>ERROR</result>
                <details code="0x00330008"><xsl:value-of select="script-log/log//log-entry[code='0x00330008']/message"/></details>
            </response>
        </xsl:when>
        <xsl:otherwise>
            <response>
                <result>ERROR</result>
                <details><xsl:text>Please check system log!</xsl:text></details>
            </response>
        </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

    <!-- ************************************************************ -->
    <!-- canonical action templates -->
    <!-- ************************************************************ -->

    <xsl:template mode="cli-actions" match="args[action]" priority="-5">
        <xsl:variable name="actName" select="action"/>
        <xsl:variable name="aNode" select="."/>
        <xsl:variable name="pNode" select="$schema/action-objects/action[@name=$actName]"/>

        <xsl:variable name="alias" select="$pNode/cli-alias"/>

        <xsl:value-of select="concat('configure terminal', $eol)"/>
        <xsl:value-of select="$alias"/>

        <xsl:for-each select="$pNode/parameters/parameter">
            <xsl:variable name="pName" select="@name"/>
            <xsl:value-of select="concat(' ', dpfunc:quoesc($aNode/*[local-name()=$pName]))"/>
        </xsl:for-each>

        <xsl:value-of select="$eol"/>
    </xsl:template>

  <!-- no error details, generic error response -->
  <xsl:template mode="cli-error-processing" priority="-5"
    match="response[(result='ERROR') and string(details)='']">
      <response>
          <result>ERROR</result>
          <details><xsl:text>An error occurred, your changes may not have been applied.</xsl:text></details>
      </response>
  </xsl:template>

  <!-- intermediate response is final response -->
  <xsl:template mode="cli-error-processing" priority="-10" match="response">
      <xsl:copy-of select="."/>
  </xsl:template>

  <xsl:template match="text()" mode="cli-object"/>
  <xsl:template match="text()" mode="cli-delete-object"/>
  <xsl:template match="text()" mode="cli-actions"/>
  <xsl:template match="text()" mode="cli-error-processing"/>

  <xsl:template match="text()" mode="DNSNameService"/>
  <xsl:template match="text()" mode="EthernetInterface"/>
  <xsl:template match="text()" mode="CRLFetch"/>
  <xsl:template match="text()" mode="CRLFetchConfig"/>
  <xsl:template match="text()" mode="HTTPService"/>
  <xsl:template match="text()" mode="NTPService"/>
  <xsl:template match="text()" mode="TimeSettings"/>
  <xsl:template match="text()" mode="Standby"/>
  <xsl:template match="text()" mode="StylePolicy"/>
  <xsl:template match="text()" mode="HTTPUserAgent"/>
  <xsl:template match="text()" mode="StylesheetRefresh"/>
  <xsl:template match="text()" mode="TCPProxyService"/>
  <xsl:template match="text()" mode="SSLProxyService"/>
  <xsl:template match="text()" mode="URLMap"/>
  <xsl:template match="text()" mode="URLRefreshPolicy"/>
  <xsl:template match="text()" mode="CompileOptionsPolicy"/>
  <xsl:template match="text()" mode="User"/>
  <xsl:template match="text()" mode="XMLManager"/>
  <xsl:template match="text()" mode="XMLManagerCanonical"/>
  <xsl:template match="text()" mode="ParserLimits"/>
  <xsl:template match="text()" mode="DocumentCache"/>
  <xsl:template match="text()" mode="XSLProxyService"/>
  <xsl:template match="text()" mode="HTTPProxyService"/>
  <xsl:template match="text()" mode="StylePolicyRule"/>
  <xsl:template match="text()" mode="Matching"/>
  <xsl:template match="text()" mode="SystemSettings"/>
  <xsl:template match="text()" mode="SNMPSettings"/>
  <xsl:template match="text()" mode="RADIUSSettings"/>
  <xsl:template match="text()" mode="UserGroup"/>
  <xsl:template match="text()" mode="ShellAlias"/>
  <xsl:template match="text()" mode="XSLCoprocService"/>
  <xsl:template match="text()" mode="TelnetService"/>
  <xsl:template match="text()" mode="LoadBalancerGroup"/>
  <xsl:template match="text()" mode="CryptoSSKey"/>
  <xsl:template match="text()" mode="URLRewritePolicy"/>
  <xsl:template match="text()" mode="SSLProxyProfile"/>
  <xsl:template match="text()" mode="CryptoEngine"/>
  <xsl:template match="text()" mode="CryptoFWCred"/>
  <xsl:template match="text()" mode="AAAPolicy"/>
  <xsl:template match="text()" mode="XMLFirewallService"/>
  <xsl:template match="text()" mode="CryptoKey"/>
  <xsl:template match="text()" mode="CryptoCertificate"/>
  <xsl:template match="text()" mode="CryptoIdentCred"/>
  <xsl:template match="text()" mode="CryptoValCred"/>
  <xsl:template match="text()" mode="CryptoProfile"/>
  <xsl:template match="text()" mode="CryptoKerberosKDC"/>
  <xsl:template match="text()" mode="LogLabel"/>
  <xsl:template match="text()" mode="LogTarget"/>
  <xsl:template match="text()" mode="DefaultLogTarget"/>
  <xsl:template match="text()" mode="MQQM"/>
  <xsl:template match="text()" mode="MQGW"/>
  <xsl:template match="text()" mode="MQhost"/>
  <xsl:template match="text()" mode="MQproxy"/>
  <xsl:template match="text()" mode="SSHService"/>
  <xsl:template match="text()" mode="HTTPUserAgent"/>
  <xsl:template match="text()" mode="Statistics"/>
  <xsl:template match="text()" mode="Throttler"/>
  <xsl:template match="text()" mode="MessageMatching"/>
  <xsl:template match="text()" mode="CountMonitor"/>
  <xsl:template match="text()" mode="DurationMonitor"/>
  <xsl:template match="text()" mode="CanonicalProperty"/>
  <xsl:template match="text()" mode="xmltrace"/>
  <xsl:template match="text()" mode="HTTPInputConversionMap"/>
  <xsl:template match="text()" mode="NetworkSettings"/>
  <xsl:template match="text()" mode="XPathRoutingMap"/>
  <xsl:template match="text()" mode="SchemaExceptionMap"/>
  <xsl:template match="text()" mode="DocumentCryptoMap"/>
  <xsl:template match="text()" mode="ErrorReportSettings"/>
  <xsl:template match="text()" mode="ACLEntry"/>
  <xsl:template match="text()" mode="ImportPackage"/>
  <xsl:template match="text()" mode="Domain"/>
  <xsl:template match="text()" mode="TAM"/>
  <xsl:template match="text()" mode="Netegrity"/>
  <xsl:template match="text()" mode="XMLMgmt"/>
  <xsl:template match="text()" mode="WebGUI"/>
  <xsl:template match="text()" mode="RBMSettings"/>
  <xsl:template match="text()" mode="SQLDataSource"/>
  <xsl:template match="text()" mode="HostAlias"/>
  <xsl:template match="text()" mode="XACMLPDP"/>
</xsl:stylesheet>
