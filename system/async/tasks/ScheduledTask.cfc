/**
 * This object represents a scheduled task that will be sent in to a scheduled executor for scheduling.
 * It has a fluent and human dsl for setting it up and restricting is scheduling and frequency of scheduling.
 *
 * A task can be represented as either a closure or a cfc with a `run()` or custom runnable method.
 */
component accessors="true" {

	/**
	 * The delay or time to wait before we execute the task in the scheduler
	 */
	property name="delay" type="numeric";

	/**
	 * A fixed time period of execution of the tasks in this schedule. It does not wait for tasks to finish,
	 * tasks are fired exactly at that time period.
	 */
	property name="period" type="numeric";

	/**
	 * The delay to use when using scheduleWithFixedDelay(), so tasks execute after this delay once completed
	 */
	property name="spacedDelay" type="numeric";

	/**
	 * The time unit string used to schedule the task
	 */
	property name="timeunit";

	/**
	 * The task closure or CFC to execute in the task
	 */
	property name="task";

	/**
	 * The method to execute if the task is a CFC
	 */
	property name="method";

	/**
	 * The human name of this task
	 */
	property name="name";

	/**
	 * A handy boolean that disables the scheduling of this task
	 */
	property name="disabled" type="boolean";

	/**
	 * A closure, that if registered, determines if this task will be sent for scheduling or not.
	 * It is both evaluated at scheduling and at runtime.
	 */
	property name="when" type="any";

	/**
	 * The timezone this task runs under, by default we use the timezone defined in the schedulers
	 */
	property name="timezone";

	/**
	 * This task can be assigned to a task scheduler or be executed on its own at runtime
	 */
	property name="scheduler";

	/**
	 * The collection of stats for the task: { created, lastRun, nextRun, totalRuns, totalFailures, totalSuccess, lastResult, neverRun, lastExecutionTime }
	 */
	property name="stats" type="struct";

	/**
	 * The before task closure
	 */
	property name="beforeTask";

	/**
	 * The after task closure
	 */
	property name="afterTask";

	/**
	 * The task success closure
	 */
	property name="onTaskSuccess";

	/**
	 * The task failure closure
	 */
	property name="onTaskFailure";

	/**
	 * Constructor
	 *
	 * @name The name of this task
	 * @executor The executor this task will run under and be linked to
	 * @task The closure or cfc that represents the task (optional)
	 * @method The method on the cfc to call, defaults to "run" (optional)
	 */
	ScheduledTask function init(
		required name,
		required executor,
		any task = "",
		method   = "run"
	){
		// Utility class
		variables.util             = new coldbox.system.core.util.Util();
		// Link up the executor and name
		variables.executor         = arguments.executor;
		variables.name             = arguments.name;
		// time unit helper
		variables.chronoUnitHelper = new coldbox.system.async.time.ChronoUnit();
		variables.timeUnitHelper   = new coldbox.system.async.time.TimeUnit();
		// System Helper
		variables.System           = createObject( "java", "java.lang.System" );
		// Init Properties
		variables.task             = arguments.task;
		variables.method           = arguments.method;
		// Default Frequencies
		variables.period           = 0;
		variables.delay            = 0;
		variables.spacedDelay      = 0;
		variables.timeUnit         = "milliseconds";
		variables.noOverlap        = false;
		// Constraints
		variables.disabled         = false;
		variables.when             = "";
		// Probable Scheduler or not
		variables.scheduler        = "";
		// Prepare execution tracking stats
		variables.stats            = {
			// When task got created
			"created"           : now(),
			// The last execution run timestamp
			"lastRun"           : "",
			// When's the next execution
			"nextRun"           : "",
			// Total runs
			"totalRuns"         : 0,
			// Total faiulres
			"totalFailures"     : 0,
			// Total successful task executions
			"totalSuccess"      : 0,
			// How long the last execution took
			"lastExecutionTime" : 0,
			// The latest result if any
			"lastResult"        : "",
			// If the task has never ran or not
			"neverRun"          : true,
			// Server Host
			"inetHost"          : variables.util.discoverInetHost(),
			// Server IP
			"localIp"           : variables.util.getServerIp()
		};
		// Life cycle methods
		variables.beforeTask    = "";
		variables.afterTask     = "";
		variables.onTaskSuccess = "";
		variables.onTaskFailure = "";

		return this;
	}

	/**
	 * --------------------------------------------------------------------------
	 * Utility and Operational
	 * --------------------------------------------------------------------------
	 */

	/**
	 * Utility to send to output to the output stream
	 *
	 * @var Variable/Message to send
	 */
	ScheduledTask function out( required var ){
		variables.System.out.println( arguments.var.toString() );
		return this;
	}

	/**
	 * Utility to send to output to the error stream
	 *
	 * @var Variable/Message to send
	 */
	ScheduledTask function err( required var ){
		variables.System.err.println( arguments.var.toString() );
		return this;
	}

	/**
	 * Set the timezone for this task using the task identifier else we default to our scheduler
	 *
	 * @see https://docs.oracle.com/en/java/javase/11/docs/api/java.base/java/time/ZoneId.html
	 *
	 * @timezone The timezone string identifier
	 */
	ScheduledTask function setTimezone( required timezone ){
		variables.timezone = createObject( "java", "java.time.ZoneId" ).of( arguments.timezone );
		return this;
	}

	/**
	 * Has this task been assigned to a scheduler or not?
	 */
	boolean function hasScheduler(){
		return isObject( variables.scheduler );
	}

	/**
	 * This method is used to register the callable closure or cfc on this scheduled task.
	 *
	 * @task The closure or cfc that represents the task
	 * @method The method on the cfc to call, defaults to "run" (optional)
	 *
	 * @return The schedule with the task/method registered on it
	 */
	ScheduledTask function call( required task, method = "run" ){
		variables.task   = arguments.task;
		variables.method = arguments.method;
		return this;
	}

	/**
	 * --------------------------------------------------------------------------
	 * Restrictions
	 * --------------------------------------------------------------------------
	 */

	/**
	 * Register a when closure that will be executed before the task is set to be registered.
	 * If the closure returns true we schedule, else we disable it.
	 */
	ScheduledTask function when( target ){
		variables.when = arguments.target;
		return this;
	}

	/**
	 * Disable the task when scheduled, meaning, don't run this sucker!
	 */
	ScheduledTask function disable(){
		variables.disabled = true;
		return this;
	}

	/**
	 * Verifies if we can schedule this task or not by looking at the following constraints:
	 *
	 * - disabled
	 * - when closure
	 */
	boolean function isDisabled(){
		// Disabled bit
		if ( variables.disabled ) {
			return true;
		}

		// When Closure that dictates if the task can be scheduled: true => yes, false => no
		if ( isClosure( variables.when ) ) {
			return !variables.when( this );
		}

		// Not disabled
		return false;
	}

	/**
	 * --------------------------------------------------------------------------
	 * Startup and Runnable Proxy
	 * --------------------------------------------------------------------------
	 */

	/**
	 * This is the runnable proxy method that executes your code by the executors
	 */
	function run(){
		var sTime = getTickCount();

		// If disabled, skip run
		if ( isDisabled() ) {
			return;
		}

		// Init now as it is running
		variables.stats.neverRun = false;

		try {
			// Before Interceptors
			if ( hasScheduler() ) {
				getScheduler().beforeAnyTask( this );
			}
			if ( isClosure( variables.beforeTask ) ) {
				variables.beforeTask( this );
			}

			// Target task call callable
			if ( isClosure( variables.task ) || isCustomFunction( variables.task ) ) {
				variables.stats.lastResult = variables.task() ?: "";
			} else {
				variables.stats.lastResult = invoke( variables.task, variables.method ) ?: "";
			}

			// After Interceptor
			if ( isClosure( variables.afterTask ) ) {
				variables.afterTask( this, variables.stats.lastResult );
			}
			if ( hasScheduler() ) {
				getScheduler().afterAnyTask( this, variables.stats.lastResult );
			}

			// store successes and call success interceptor
			variables.stats.totalSuccess = variables.stats.totalSuccess + 1;
			if ( isClosure( variables.onTaskSuccess ) ) {
				variables.onTaskSuccess( this, variables.stats.lastResult );
			}
			if ( hasScheduler() ) {
				getScheduler().onAnyTaskSuccess( this, variables.stats.lastResult );
			}
		} catch ( any e ) {
			// store failures
			variables.stats.totalFailures = variables.stats.totalFailures + 1;
			// Life Cycle
			if ( isClosure( variables.onTaskFailure ) ) {
				variables.onTaskFailure( this, e );
			}
			if ( hasScheduler() ) {
				getScheduler().onAnyTaskError( this, e );
			}
		} finally {
			// Store finalization stats
			variables.stats.lastRun           = now();
			variables.stats.totalRuns         = variables.stats.totalRuns + 1;
			variables.stats.lastExecutionTime = getTickCount() - sTime;
		}
	}

	/**
	 * This method registers the task into the executor and sends it for execution and scheduling.
	 * This will not register the task for execution if the disabled flag or the constraints allow it.
	 *
	 * @return A ScheduledFuture from where you can monitor the task, an empty ScheduledFuture if the task was not registered
	 */
	ScheduledFuture function start(){
		// Startup a spaced frequency task
		if ( variables.spacedDelay > 0 ) {
			return variables.executor.scheduleWithFixedDelay(
				task       : this,
				spacedDelay: variables.spacedDelay,
				delay      : variables.delay,
				timeUnit   : variables.timeUnit,
				method     : "run"
			);
		}

		// Startup a task with a frequency period
		if ( variables.period > 0 ) {
			return variables.executor.scheduleAtFixedRate(
				task    : this,
				every   : variables.period,
				delay   : variables.delay,
				timeUnit: variables.timeUnit,
				method  : "run"
			);
		}

		// Start off a one-off task
		return variables.executor.schedule(
			task    : this,
			delay   : variables.delay,
			timeUnit: variables.timeUnit,
			method  : "run"
		);
	}

	/**
	 * --------------------------------------------------------------------------
	 * Life - Cycle Methods
	 * --------------------------------------------------------------------------
	 */

	/**
	 * Store the closure to execute before the task is executed
	 *
	 * @target The closure to execute
	 */
	ScheduledTask function before( required target ){
		variables.beforeTask = arguments.target;
		return this;
	}

	/**
	 * Store the closure to execute after the task is executed
	 *
	 * @target The closure to execute
	 */
	ScheduledTask function after( required target ){
		variables.afterTask = arguments.target;
		return this;
	}

	/**
	 * Store the closure to execute after the task is executed successfully
	 *
	 * @target The closure to execute
	 */
	ScheduledTask function onSuccess( required target ){
		variables.onTaskSuccess = arguments.target;
		return this;
	}

	/**
	 * Store the closure to execute after the task is executed successfully
	 *
	 * @target The closure to execute
	 */
	ScheduledTask function onFailure( required target ){
		variables.onTaskFailure = arguments.target;
		return this;
	}

	/**
	 * --------------------------------------------------------------------------
	 * Frequency Methods
	 * --------------------------------------------------------------------------
	 */

	/**
	 * Set a delay in the running of the task that will be registered with this schedule
	 *
	 * @delay The delay that will be used before executing the task
	 * @timeUnit The time unit to use, available units are: days, hours, microseconds, milliseconds, minutes, nanoseconds, and seconds. The default is milliseconds
	 */
	ScheduledTask function delay( numeric delay, timeUnit = "milliseconds" ){
		variables.delay    = arguments.delay;
		variables.timeUnit = arguments.timeUnit;
		return this;
	}

	/**
	 * Set the spaced delay between the executions of this scheduled task
	 *
	 * @delay The delay that will be used before executing the task
	 * @timeUnit The time unit to use, available units are: days, hours, microseconds, milliseconds, minutes, nanoseconds, and seconds. The default is milliseconds
	 */
	ScheduledTask function spacedDelay( numeric spacedDelay, timeUnit = "milliseconds" ){
		variables.spacedDelay = arguments.spacedDelay;
		variables.timeUnit    = arguments.timeUnit;
		return this;
	}

	/**
	 * Set the period of execution for the schedule
	 *
	 * @period The period of execution
	 * @timeUnit The time unit to use, available units are: days, hours, microseconds, milliseconds, minutes, nanoseconds, and seconds. The default is milliseconds
	 */
	ScheduledTask function every( numeric period, timeUnit = "milliseconds" ){
		variables.period   = arguments.period;
		variables.timeUnit = arguments.timeUnit;
		return this;
	}

	/**
	 * Set the period to be every minute from the time it get's scheduled
	 */
	ScheduledTask function everyMinute(){
		variables.period   = 1;
		variables.timeUnit = "minutes";
		return this;
	}

	/**
	 * Set the period to be every hour from the time it get's scheduled
	 */
	ScheduledTask function everyHour(){
		variables.period   = 1;
		variables.timeUnit = "hours";
		return this;
	}

	/**
	 * Set the period to be every day from the time it get's scheduled
	 */
	ScheduledTask function everyDay(){
		variables.period   = 1;
		variables.timeUnit = "days";
		return this;
	}

	/**
	 * Set the period to be every week (7 days) from the time it get's scheduled
	 */
	ScheduledTask function everyWeek(){
		variables.period   = 7;
		variables.timeUnit = "days";
		return this;
	}

	/**
	 * Set the period to be every month (30 days) from the time it get's scheduled
	 */
	ScheduledTask function everyMonth(){
		variables.period   = 30;
		variables.timeUnit = "days";
		return this;
	}

	/**
	 * Set the period to be every year (365 days) from the time it get's scheduled
	 */
	ScheduledTask function everyYear(){
		variables.period   = 365;
		variables.timeUnit = "days";
		return this;
	}

	/**
	 * Set the period to be hourly at a specific minute mark
	 *
	 * @minutes The minutes past the hour mark
	 */
	ScheduledTask function everyHourAt( required numeric minutes ){
		// Get times
		var now     = variables.chronoUnitHelper.toLocalDateTime( now() );
		var nextRun = now.withMinute( javacast( "int", arguments.minutes ) );
		// If we passed it, then move the hour by 1
		if ( now.compareTo( nextRun ) > 0 ) {
			nextRun = nextRun.plusHours( javacast( "int", 1 ) )
		}
		// Get the duration time for the next run and delay accordingly
		this.delay(
			variables.chronoUnitHelper
				.duration()
				.getNative()
				.between( now, nextRun )
				.getSeconds(),
			"seconds"
		);
		// Set the period to every day in seconds
		variables.period   = variables.timeUnitHelper.get( "hours" ).toSeconds( 1 );
		variables.timeUnit = "seconds";

		return this;
	}

	/**
	 * Set the period to be daily at a specific time
	 *
	 * @time The specific time using 24 hour format => HH:mm
	 */
	ScheduledTask function everyDayAt( required string time ){
		// Check for mintues else add them
		if ( !find( ":", arguments.time ) ) {
			arguments.time &= ":00";
		}
		// Validate it
		validateTime( arguments.time );
		// Get times
		var now     = variables.chronoUnitHelper.toLocalDateTime( now() );
		var nextRun = now
			.withHour( javacast( "int", getToken( arguments.time, 1, ":" ) ) )
			.withMinute( javacast( "int", getToken( arguments.time, 2, ":" ) ) );
		// If we passed it, then move the day
		if ( now.compareTo( nextRun ) > 0 ) {
			nextRun = nextRun.plusDays( javacast( "int", 1 ) )
		}
		// Get the duration time for the next run and delay accordingly
		this.delay(
			variables.chronoUnitHelper
				.duration()
				.getNative()
				.between( now, nextRun )
				.getSeconds(),
			"seconds"
		);
		// Set the period to every day in seconds
		variables.period   = variables.timeUnitHelper.get( "DAYS" ).toSeconds( 1 );
		variables.timeUnit = "seconds";

		return this;
	}

	/**
	 * Set the period to be weekly at a specific time at a specific day of the week
	 *
	 * @dayOfWeek The day of the week from 1 (Monday) -> 7 (Sunday)
	 * @time The specific time using 24 hour format => HH:mm
	 */
	ScheduledTask function everyWeekOn( required dayOfWeek, required string time ){
		return this;
	}

	/**
	 * Set the period to be weekly at a specific time at a specific day of the week
	 *
	 * @day Which day of the month
	 * @time The specific time using 24 hour format => HH:mm
	 */
	ScheduledTask function everyMonthOn( required day, required string time ){
		return this;
	}

	/**
	 * Set the period to be weekly at a specific time at a specific day of the week
	 *
	 * @month The month in numeric format 1-12
	 * @day Which day of the month
	 * @time The specific time using 24 hour format => HH:mm, defaults to 00:00
	 */
	ScheduledTask function everyYearOn(
		required numeric month,
		required numeric day,
		required string time = "00:00"
	){
		return this;
	}

	/**
	 * Set the period to be the first day of the month
	 *
	 * @time The specific time using 24 hour format => HH:mm, defaults to 00:00
	 */
	ScheduledTask function firstDayOfTheMonth( string time = "00:00" ){
		return this;
	}

	/**
	 * Set the period to be the first business day of the month
	 *
	 * @time The specific time using 24 hour format => HH:mm, defaults to 00:00
	 */
	ScheduledTask function firstBusinessDayOfTheMonth( string time = "00:00" ){
		return this;
	}

	/**
	 * Set the period to be the last day of the month
	 *
	 * @time The specific time using 24 hour format => HH:mm, defaults to 00:00
	 */
	ScheduledTask function lastDayOfTheMonth( string time = "00:00" ){
		return this;
	}

	/**
	 * Set the period to be the last business day of the month
	 *
	 * @time The specific time using 24 hour format => HH:mm, defaults to 00:00
	 */
	ScheduledTask function lastBusinessDayOfTheMonth( string time = "00:00" ){
		return this;
	}

	/**
	 * Set the period to be on saturday and sundays
	 *
	 * @time The specific time using 24 hour format => HH:mm, defaults to 00:00
	 */
	ScheduledTask function weekends( string time = "00:00" ){
		return this;
	}

	/**
	 * Set the period to be from Monday - Friday
	 *
	 * @time The specific time using 24 hour format => HH:mm, defaults to 00:00
	 */
	ScheduledTask function weekdays( string time = "00:00" ){
		return this;
	}

	/**
	 * --------------------------------------------------------------------------
	 * TimeUnit Methods
	 * --------------------------------------------------------------------------
	 */

	/**
	 * Set the time unit in days
	 */
	ScheduledTask function inDays(){
		variables.timeUnit = "days";
		return this;
	}

	/**
	 * Set the time unit in hours
	 */
	ScheduledTask function inHours(){
		variables.timeUnit = "hours";
		return this;
	}

	/**
	 * Set the time unit in microseconds
	 */
	ScheduledTask function inMicroseconds(){
		variables.timeUnit = "microseconds";
		return this;
	}

	/**
	 * Set the time unit in milliseconds
	 */
	ScheduledTask function inMilliseconds(){
		variables.timeUnit = "milliseconds";
		return this;
	}

	/**
	 * Set the time unit in minutes
	 */
	ScheduledTask function inMinutes(){
		variables.timeUnit = "minutes";
		return this;
	}

	/**
	 * Set the time unit in nanoseconds
	 */
	ScheduledTask function inNanoseconds(){
		variables.timeUnit = "nanoseconds";
		return this;
	}

	/**
	 * Set the time unit in seconds
	 */
	ScheduledTask function inSeconds(){
		variables.timeUnit = "seconds";
		return this;
	}

	/**
	 * Validates an incoming string to adhere to either: HH:mm
	 *
	 * @time The time to check
	 *
	 * @throws InvalidTimeException - If the time is invalid, else it just continues operation
	 */
	private function validateTime( required time ){
		// Regex check
		if ( !reFind( "^[0-2][0-4]\:[0-5][0-9]$", arguments.time ) ) {
			throw(
				message = "Invalid time representation. Time is represented in 24 hour minute format => HH:mm",
				type    = "InvalidTimeException"
			);
		}
	}

}
