#Monq = Npm.require("monq")(process.env.MONGO_URL)

withJobs = (cb) ->
  _.each global, (val, key) ->
    cb(val, key) if s.endsWith(key, "Job") and key isnt "Job"


Cluster.startupMaster ->
  count = Jobs.update status: "dequeued",
    $set: status: "queued"
  , multi: true
  Cluster.log "Requeued #{count} jobs."

  unless Meteor.settings?.workers?.cron?.disable
    SyncedCron.options =
      log: Meteor.settings?.workers?.cron?.log
      utc: true
      collectionName: "scheduler"

    withJobs (val, key) ->
      if global[key].setupCron?

        SyncedCron.add
          name: "#{key} (Cron)"
          schedule: global[key].setupCron
          job: ->
            Job.push new global[key]

    SyncedCron.start()


Cluster.startupWorker ->
  monqWorkers = Meteor.settings?.workers?.count or 1
  i = 0
  while i < monqWorkers
    i++
    Meteor.setTimeout ->
      claimAndProcessNextJob = ->
        #Cluster.log 'claimAndProcessNextJob', Jobs.find().fetch()
        query =
            status: 'queued'
            queue: 'jobs'
            delay: $lte: new Date()
        update =
          $set:
            status: 'dequeued'
            dequeued: new Date()
        options =
          sort:
            [['priority', 'desc'], ['_id', 'asc']]
          returnNewDocument: true
          upsert: false

        Future = Npm.require 'fibers/future'
        f = new Future()
        #Jobs.rawCollection().findAndModify query, sort, update, options, Meteor.bindEnvironment (err, jobDoc) ->
        res = Jobs.rawCollection().findOneAndUpdate query, update, options
        res
          .then Meteor.bindEnvironment (jobDoc) ->
            if jobDoc? and jobDoc.value?
              jobDoc = jobDoc.value
              # Find globally registered Job class which matches the type
              if not global[jobDoc._className]?
                throw new Error "No handler for job of class #{jobDoc._className}"

              Job.handler jobDoc, Meteor.bindEnvironment (err, res) ->
                return
            else
              # No job is available, so observe until something comes up...
              ready = false
              f2 = new Future()
              delete query.delay
              handle = Jobs.find(query).observe
                added: ->
                  if ready
                    f2.return()
              ready = true
              f2.wait()
              handle.stop()

            f.return()
          .catch (err) ->
            console.log "Error retrieving job from queue: ", err

        f.wait()

        Meteor.setTimeout claimAndProcessNextJob, 0

      claimAndProcessNextJob()
    , 100 * i

  Cluster.log "Started #{monqWorkers} workers."

