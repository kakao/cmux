module CMUX
  ### CMUX
  # CMUX directories
  CMUX_HOME = File.expand_path('../..', __dir__).freeze
  CONF_HOME = File.join(CMUX_HOME, 'config').freeze
  LIB_HOME  = File.join(CMUX_HOME, 'lib').freeze
  DATA_HOME = File.join(CMUX_HOME, 'data').freeze
  HRI_HOME  = File.join(CMUX_HOME, 'lib/hbase-region-inspector').freeze
  HT_HOME   = File.join(CMUX_HOME, 'lib/hbase-tools').freeze

  # CMUX files
  CMUX_YAML   = File.join(CONF_HOME, 'cmux.yaml').freeze
  IRBRC       = File.join(LIB_HOME,  'irbrc').freeze
  SCMAGENT_SH = File.join(LIB_HOME,  'cmux_scmagent.sh').freeze
  CM_LIST     = File.join(CONF_HOME, 'cm.yaml').freeze
  IRBRC_LOCAL = File.join(CONF_HOME, 'irbrc.local').freeze
  CMUX_DATA   = File.join(DATA_HOME, 'cmux.data').freeze

  # CMUX table headers.
  TABLE_HEADERS = {
    cm:           'Cloudera Manager',
    cm_ver:       'CM Ver',
    cm_api_ver:   'CM API Ver',
    cl:           'Cluster',
    cl_disp:      'Cludera Display Name',
    cdh_ver:      'CDH Ver',
    hosts:        'Hosts',
    hostid:       'HostID',
    hostname:     'Hostname',
    ipaddress:    'IP Address',
    serviceType:  'Service Type',
    serviceName:  'Service',
    roleType:     'Role Type',
    roleHealth:   'Health',
    roleMOwners:  'Maintenance',
    role_stypes:  'Roles',
    roleHAStatus: 'HA Status',
    rackid:       'RackID-CM',
    level:        'Level',
    url:          'URL'
  }.freeze

  ### rolling-restart-roles
  # Do not run rolling-restart-roles for these roles
  RR_EXCEPT_ROLES = %w[
    BALANCER GATEWAY ACTIVITYMONITOR HOSTMONITOR EVENTSERVER
    SERVICEMONITOR ALERTPUBLISHER
  ].freeze

  ### hbase-region-inspector
  # default port
  HRI_PORT = 7778
  CDH_HRI_VER_MAP = {
    '5.0' => '',
    '4.0' => 'cdh4'
  }.freeze

  ### hbase-tools
  # default port
  HTS_PORT = 6667
  CDH_HT_VER_MAP = {
    '5.8' => '1.2',
    '5.6' => '1.0',
    '5.3' => '0.98',
    '5.0' => '0.96',
    '4.0' => '0.94'
  }.freeze

  ### scmagent
  SCMAGENT_ARGS = %w[
    start stop restart clean_start hard_stop hard_restart clean_restart
    status condrestart
  ].freeze

  ### shell
  C_0   = 'tput sgr 0'.freeze
  C_B   = 'tput setaf 4'.freeze
  SPIN  = ['-', '\\', '|', '/'].freeze
  ANSI  = /\e\[[0-9,]+m/
  BOXES = 'boxes -d peek -p a1l2r2'.freeze

  ### websvc
  ROLE_PORT = {
    'NAMENODE'        => '50070',
    'MASTER'          => '60010',
    'REGIONSERVER'    => '60030',
    'RESOURCEMANAGER' => '8088',
    'JOBHISTORY'      => '19888',
    'SOLR_SERVER'     => '8983',
    'KUDU_MASTER'     => '8051',
    'HUE_SERVER'      => '8888',
    'OOZIE_SERVER'    => '11000'
  }.freeze

  ### API
  # Supported API Version
  CM_API_MAP = {
    '5.9' => 'v14',
    '5.8' => 'v13',
    '5.7' => 'v12',
    '5.5' => 'v11',
    '5.4' => 'v10',
    '5.3' => 'v9',
    '5.2' => 'v8',
    '5.1' => 'v7',
    '5.0' => 'v6',
    '4.7' => 'v5',
    '4.6' => 'v4',
    '4.5' => 'v3',
    '4.1' => 'v2',
    '4.0' => 'v1'
  }.freeze

  ### Roles
  # Role types are required to check HA status
  HA_RTYPES = %w[MASTER NAMENODE RESOURCEMANAGER].freeze

  # Role types are required to check HA status and Zookeeper server
  CHK_RTYPES = %w[MASTER NAMENODE RESOURCEMANAGER SERVER].freeze

  # Role types
  ROLE_TYPES = {
    # Cloudera Manager
    'ALERTPUBLISHER'             => 'ALRP',
    'SERVICEMONITOR'             => 'SMON',
    'EVENTSERVER'                => 'EVTS',
    'HOSTMONITOR'                => 'HMON',
    'ACTIVITYMONITOR'            => 'AMON',
    'REPORTSMANAGER'             => 'RM',
    # HDFS
    'NAMENODE'                   => 'NN',
    'DATANODE'                   => 'DN',
    'SECONDARYNAMENODE'          => 'SNN',
    'BALANCER'                   => 'BL',
    'HTTPFS'                     => 'HFS',
    'FAILOVERCONTROLLER'         => 'FC',
    'GATEWAY'                    => 'G',
    'JOURNALNODE'                => 'JN',
    'NFSGATEWAY'                 => 'NFSG',
    # MAPREDUCE
    'JOBTRACKER'                 => 'JT',
    'TASKTRACKER'                => 'TT',
    # HBASE
    'MASTER'                     => 'HM',
    'REGIONSERVER'               => 'RS',
    'HBASETHRIFTSERVER'          => 'HBTS',
    'HBASERESTSERVER'            => 'HBRES',
    # YARN
    'RESOURCEMANAGER'            => 'RM',
    'NODEMANAGER'                => 'NM',
    'JOBHISTORY'                 => 'JHS',
    # OOZIE
    'OOZIE_SERVER'               => 'OS',
    # ZOOKEEPER
    'SERVER'                     => 'ZK',
    # HUE
    'HUE_SERVER'                 => 'H',
    'KT_RENEWER'                 => 'K',
    'HUE_LOAD_BALANCER'          => 'HLB',
    # FLUME
    'AGENT'                      => 'A',
    # IMPALA
    'IMPALAD'                    => 'ID',
    'STATESTORE'                 => 'ISS',
    'CATALOGSERVER'              => 'ICS',
    # HIVE
    'HIVESERVER2'                => 'HS2',
    'HIVEMETASTORE'              => 'HMS',
    'WEBHCAT'                    => 'WHCS',
    # SOLR
    'SOLR_SERVER'                => 'SS_SOLR',
    # SQOOP
    'SQOOP_SERVER'               => 'S2S',
    # SENTRY
    'SENTRY_SERVER'              => 'SS_SENTRY',
    # KS_INDEXER
    'HBASE_INDEXER'              => 'HI',
    # SPARK_ON_YARN
    'SPARK_YARN_HISTORY_SERVER'  => 'HS',
    'SPARK2_YARN_HISTORY_SERVER' => 'HS',
    # KUDU
    'KUDU_MASTER'                => 'M',
    'KUDU_TSERVER'               => 'TS',
    # KAFKA
    'KAFKA_BROKER'               => 'KB',
    'KAFKA_MIRRORMAKER'          => 'KMM',
    'KAFKA_MANAGER_WEB_UI'       => 'KMWU',
    # MESOS
    'MESOS_MASTER_SERVER'        => 'MMS',
    'MESOS_SLAVE_SERVER'         => 'MSS',
    'MESOS_MARATHON'             => 'M',
    # DOCKER
    'DOCKER_DAEMON'              => 'D'
  }.freeze
end
