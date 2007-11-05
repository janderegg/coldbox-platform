<!-----------------------------------------------------------------------
********************************************************************************
Copyright 2005-2007 ColdBox Framework by Luis Majano and Ortus Solutions, Corp
www.coldboxframework.com | www.luismajano.com | www.ortussolutions.com
********************************************************************************

Author     :	Luis Majano
Date        :	10/16/2007
Description :
	This component is the coldbox remote proxy used for model operation.
	This will convert the framework into a model framework rather than a 
	HTML MVC framework.	
----------------------------------------------------------------------->
<cfcomponent name="cf8ColdboxRemoteProxy" output="false" hint="This component is the coldbox remote proxy used for model operation using ColdFusion 8's on missing method." >
	
<!------------------------------------------- PUBLIC ------------------------------------------->	

	<!--- process an interception --->
	<cffunction name="announceInterception" output="false" access="remote" returntype="boolean" hint="Process a remote interception.">
		<!--- ************************************************************* --->
		<cfargument name="state" 			type="string" 	required="true" hint="The intercept state"/>
		<cfargument name="interceptData"    type="any" 	    required="false" default="" hint="This method will take the contents and embedded into a structure"/>
		<!--- ************************************************************* --->
		<cfscript>
			var cbController = "";
			var interceptionStructure = structnew();
			
			//Verify the coldbox app is ok, else throw
			if ( verifyColdBox() ){
				cbController = application.cbController;
			}
			
			//emded contents
			interceptionStructure.interceptData = arguments.interceptData;
			
			//Intercept
			try{
				cbController.getInterceptorService().processState(arguments.state,interceptionStructure);
			}
			catch(Any e){
				//Log Exception
				cbController.getService("exception").ExceptionHandler(e,"coldboxproxy","Interception Exception");
				return false;
			}
			return true;
		</cfscript>
	</cffunction>
	
	<!--- The main entry point for processing --->
	<cffunction name="onMissingMethod" output="false" access="remote" returntype="Any" hint="Process a remote call and return data/objects back.">
    	<!--- ************************************************************* --->
		<cfargument name="missingMethodName"		type="string" required="true"/>
      	<cfargument name="missingMethodArguments"   type="struct" required="true"/>
      	<!--- ************************************************************* --->
		<cfscript>
			var cbController = "";
			var event = "";
			var results = "";
			
			//Verify the coldbox app is ok, else throw
			if ( verifyColdBox() ){
				cbController = application.cbController;
			}
			
			try{
				//Add the called event to the arguments as the app's event
				arguments.missingMethodArguments[cbController.getSetting("EventName")] = arguments.missingMethodName;
				
				//Create the request context
				Event = cbController.getRequestService().requestCapture();
				//Append the arguments to the collection
				Event.collectionAppend(arguments.missingMethodArguments,true);
				//Set that this is a proxy request.
				Event.setProxyRequest();
				
				//Execute the app start handler if not fired already
				if ( cbController.getSetting("ApplicationStartHandler") neq "" and (not cbController.getAppStartHandlerFired()) ){
					cbController.runEvent(cbController.getSetting("ApplicationStartHandler"),true);
					cbController.setAppStartHandlerFired(true);
				}
				
				//Execute a pre process interception.
				cbController.getInterceptorService().processState("preProcess");
				
				//Request Start Handler if defined
				if ( cbController.getSetting("RequestStartHandler") neq "" ){
					cbController.runEvent(cbController.getSetting("RequestStartHandler"),true);
				}
					
				//Execute the Event
				results = cbController.runEvent();
				
				//Request END Handler if defined
				if ( cbController.getSetting("RequestEndHandler") neq "" ){
					cbController.runEvent(cbController.getSetting("RequestEndHandler"),true);
				}
				
				//Execute the post process interceptor
				cbController.getInterceptorService().processState("postProcess");
			}
			catch(Any e){
				//Log Exception
				cbController.getService("exception").ExceptionHandler(e,"coldboxproxy","Process Exception");
				throw(e.message,e.detail & e.stacktrace,e.type);
			}
			
			//Determine what to return via the setting
			if ( cbController.getSetting("ProxyReturnCollection") ){
				//Return request collection
				return Event.getCollection();
			}
			else{
				//Return results from handler
				return results;
			}
		</cfscript>
   </cffunction>

<!------------------------------------------- PRIVATE ------------------------------------------->	
	
	<!--- verifyColdBox --->
	<cffunction name="verifyColdBox" output="false" access="private" returntype="boolean" hint="Verify the coldbox app">
		<cfscript>
		//Verify the coldbox app is ok, else throw
		if ( not structKeyExists(application,"cbController") ){
			throw("ColdBox Not Found", "The coldbox main controller has not been initialized", "framework.controllerNotFoundException");
		}
		else
			return true;
		</cfscript>
	</cffunction>

	<!--- Throw Facade --->
	<cffunction name="throw" access="private" hint="Facade for cfthrow" output="false">
		<!--- ************************************************************* --->
		<cfargument name="message" 	type="string" 	required="yes">
		<cfargument name="detail" 	type="string" 	required="no" default="">
		<cfargument name="type"  	type="string" 	required="no" default="Framework">
		<!--- ************************************************************* --->
		<cfthrow type="#arguments.type#" message="#arguments.message#"  detail="#arguments.detail#">
	</cffunction>
	
</cfcomponent>