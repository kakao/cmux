module CMUX
  # CMUX utilities.
  module Utils
    # CMUX Utilies for hbase-region-inspector.
    module HBaseRegionInspector
      class << self
        # The hbase-region-inspector for this CDH version.
        def hri4cdh(cdh_ver)
          hri_ver = Utils.version_map(CDH_HRI_VER_MAP, cdh_ver)
          pattern = 'hbase-region-inspector'
          tools   = Dir.entries(HRI_HOME).select { |e| e.match(/^#{pattern}/) }
          hri_ver == 'cdh4' ? tools.last : tools.first
        end

        # Make hbase-region-inspector configuration files.
        def gen_krb_opt(cm, zk, zk_port)
          krb5conf, keytab, principal_primary = Utils.chk_krb_opt(cm, 'hbase')
          rand_name      = SecureRandom.hex
          jass_conf      = %(/tmp/#{rand_name}-jass.conf)
          properties     = %(/tmp/#{rand_name}.properties)
          realm          = CM.security_realm(cm)
          principal      = %(#{principal_primary}/_HOST@#{realm})

          make_jass_conf(jass_conf, keytab, principal_primary)
          make_properties(properties, zk, zk_port, principal,
                          krb5conf, jass_conf)
          properties
        end

        # Make hbase-region-inspector JAAS login configuration file.
        def make_jass_conf(file_name, keytab, principal)
          str = %(Client {\n) +
                %(  com.sun.security.auth.module.Krb5LoginModule required\n) +
                %(  useTicketCache=false\n) +
                %(  useKeyTab=true\n) +
                %(  keyTab="#{keytab}"\n) +
                %(  principal="#{principal}";\n};)
          File.open(file_name, 'w') { |file| file.write str }
        end

        # Make hbase-region-inspector properties file.
        def make_properties(*args)
          file_name, zk, zk_port, principal, krb5conf, jass_conf = args
          str = %(hbase.zookeeper.quorum = #{zk}\n) +
                %(hbase.zookeeper.property.clientPort = #{zk_port}\n) +
                %(hadoop.security.authentication = kerberos\n) +
                %(hbase.security.authentication = kerberos\n) +
                %(hbase.master.kerberos.principal = #{principal}\n) +
                %(hbase.regionserver.kerberos.principal = #{principal}\n) +
                %(java.security.krb5.conf = #{krb5conf}\n) +
                %(java.security.auth.login.config = #{jass_conf}\n)
          File.open(file_name, 'w') { |file| file.write str }
        end
      end
    end
  end
end
