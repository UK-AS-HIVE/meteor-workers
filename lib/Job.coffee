#Monq = Npm.require("monq")(process.env.MONGO_URL)
#queue = Monq.queue "jobs"

#
# Abstract Job class for all actual jobs to subclass
# - Shared between master and worker processes
#
class Job

  constructor: (@params = {}) ->


  @push = (job, options, callback) ->
    if _.isFunction options
      callback = options
      options = {}

    if callback
      callback = Meteor.bindEnvironment callback
    else
      callback = (error, job) ->
        if error then Workers.log "Error enqueing job:", error
        error?

    defaultOptions = attempts: count: 10, delay: 10000, strategy: "exponential"
    settingsOptions = Meteor.settings?.workers?.monq
    options = _.extend defaultOptions, settingsOptions, options

    className = job.constructor.name

    #job.params._id = Random.id()
    #job.params._className = className

    #params = job.params

    #queue.enqueue className, params, options, callback
    Jobs.insert
      _className: className
      name: className
      params: job.params
      queue: 'jobs'
      attempts:
        count: 10
        delay: 10000
        strategy: 'exponential'
      timeout: 10
      status: 'queued'
      enqueued: new Date()
      delay: new Date()
      priority: 0


  # Generic job handler for all jobs
  # - Evaluates the job type specified in Job.push
  #   and instantiates an approriate handler and runs handleJob.
  @handler: (job, callback) ->
    # Instantiate approprite job handler
    className = job._className
    handler = new global[className](job.params)

    _ex = null

    try
      # Before hook
      handler.beforeJob()

      # Handle the job
      result = handler.handleJob()

      # Forward results to monq callback
      #callback null, result
      Jobs.update job._id, $set: status: 'complete'

    catch ex
      _ex = ex
      Cluster.log "Error in #{className} handler:\n", _ex
      Jobs.update job._id, $set: status: 'failed'
      #callback ex

    finally
      # After hook
      handler.afterJob _ex

  # Specific job classes should implement this
  # - Error handlers are fiber/meteor aware as usual
  # - Throw errors from handler if you cannot handle message for any reason
  # - Return value of handleJob will be put in the result hash on the job
  handleJob: ->
    throw new Error "Message handler not implemented!"

  # Job lifecycle callbacks
  beforeJob: ->

  afterJob: (exception) ->

  # Get the monq related data
  getMetadata: (id) ->
    Jobs.findOne "params._id": id,
      fields: params: false
