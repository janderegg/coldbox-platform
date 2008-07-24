<!-----------------------------------------------------------------------********************************************************************************Copyright 2005-2008 ColdBox Framework by Luis Majano and Ortus Solutions, Corpwww.coldboxframework.com | www.luismajano.com | www.ortussolutions.com********************************************************************************Author: Luis MajanoDate:   September 27, 2005Description: This is the framework's logger object. It performs all necessary			 loggin procedures.Modifications:09/25/2005 - Created the template.10/13/2005 - Updated the reqCollection to the request scope.12/18/2005 - Using mailserverSettings from config.xml now, fixed structnew for default to logError12/20/2005 - Bug on spaces for log files.02/16/2006 - Fixes for subjects06/28/2006 - Updates for coldbox07/12/2006 - Tracer updates01/20/2007 - Update for new bean types and formatting.02/10/2007 - Updated for 1.2.0-----------------------------------------------------------------------><cfcomponent name="MTlogger"			 hint="This is the frameworks Multi Threaded logger object. It is used for all logging facilities."			 extends="logger"			 output="false"			 cache="true"><!------------------------------------------- CONSTRUCTOR ------------------------------------------->	<cffunction name="init" access="public" returntype="logger" hint="Constructor" output="false">		<!--- ************************************************************* --->		<cfargument name="controller" type="any" required="true">		<!--- ************************************************************* --->		<cfscript>			super.Init(arguments.controller);			setThread(createObject("java", "java.lang.Thread"));			return this;		</cfscript>	</cffunction>	<!------------------------------------------- PUBLIC ------------------------------------------->	<!--- Log an entry --->	<cffunction name="logEntry" access="public" hint="Log a message to the Coldfusion/Coldbox Logging Facilities if enabled via the config" output="false" returntype="void">		<!--- ************************************************************* --->		<cfargument name="Severity" 		type="string" 	required="yes">		<cfargument name="Message" 			type="string"  	required="yes" hint="The message to log.">		<cfargument name="ExtraInfo"		type="string"   required="no"  default="" hint="Extra information to append.">		<!--- ************************************************************* --->		<!--- if we're inside a cfthread, run syncronously --->		<cfset var ThreadName = "coldbox.plugins.MTlogger.logEntry_#replace(createUUID(),"-","","all")#">				<cfif isInsideCFThread()>			<cfscript>				super.logEntry(argumentCollection=arguments);			</cfscript>		<cfelse>			<cfthread name="#threadName#"			          Severity="#arguments.severity#"			          Message="#arguments.Message#"			          ExtraInfo="#arguments.ExtraInfo#"> 				<cfscript>  					super.logEntry(Attributes.Severity,Attributes.Message,Attributes.ExtraInfo); 				</cfscript>			</cfthread>		</cfif>	</cffunction><!------------------------------------------- PRIVATE ------------------------------------------->	<!--- Email a Bug Report --->	<cffunction name="emailBugReport" access="private" returntype="void" hint="Email a bug report" output="false" >		<!--- ************************************************************* --->		<cfargument name="bugReport" required="true" type="string" hint="The bug report">		<!--- ************************************************************* --->		<cfset var ThreadName = "coldbox.plugins.MTlogger.emailBugReport_#replace(createUUID(),"-","","all")#">				<!--- if we're inside a cfthread, run syncronously --->		<cfif isInsideCFThread()>			<cfscript>				super.emailBugReport();			</cfscript>		<cfelse>			<cfthread name="#threadName#" bugReport="#arguments.bugReport#">  				<cfscript>  					super.emailBugReport(attributes.bugReport); 				</cfscript>			</cfthread>		</cfif>			</cffunction>		<!--- Is iniside cfthread checks --->	<cffunction name="isInsideCFThread" access="private" returntype="boolean" hint="See if the running thread is inside a cfthread." output="false" >		<cfscript>			try{				if ( findNoCase("cfthread", getThread().currentThread().getThreadGroup().getName() ) ){					return true;				}				else{					return false;				}			}			catch(Any e){ 				return true;			}		</cfscript>
	</cffunction>		<!--- Get/set thread object --->	<cffunction name="getThread" access="private" returntype="any" output="false">		<cfreturn instance.Thread />	</cffunction>		<cffunction name="setThread" access="private" returntype="void" output="false">		<cfargument name="Thread" type="any" required="true">		<cfset instance.Thread = arguments.Thread />	</cffunction>		</cfcomponent>