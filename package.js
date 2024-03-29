Package.describe({
  name: 'hive:workers',
  summary: 'Spawn headless worker meteor processes to work on async jobs',
  version: '2.1.0',
  git: 'https://github.com/UK-AS-HIVE/meteor-workers'
});

Package.onUse(function(api) {
  api.versionsFrom('1.0');

  api.use([
    'coffeescript',
    'mongo',
    'random',
    'underscore',
    'littledata:synced-cron',
    'underscorestring:underscore.string@3.2.2'
  ], 'server');

  api.addFiles([
    'collections/jobs.coffee',
    'lib/cluster.js',
    'lib/Job.coffee',
    'lib/init.coffee'
  ], 'server');

  api.export(['Job', 'Jobs', 'Cluster'], 'server');
});
