module CMUX
  # CMUX utilities.
  module Utils
    # CMUX Utilies for hbase-tools.
    module HBaseTools
      class << self
        # The hbase-tools for this CHD version.
        def ht4cdh(args = {})
          ht_ver  = Utils.version_map(CDH_HT_VER_MAP, args[:cdh_ver])
          pattern = "#{args[:tool]}-#{ht_ver}"
          Dir.entries(HT_HOME).find { |e| e.match(/^#{pattern}/) }
        end

        # Generate kerberos options for hbase-tools.
        def gen_krb_opt(cm)
          krb5conf, keytab, principal_primary = Utils.chk_krb_opt(cm, 'hbase')
          " --principal=#{principal_primary} --keytab=#{keytab}" \
          " --krbconf=#{krb5conf}"
        end

        # Generate a hbase-manager command.
        def gen_hbase_manager_command(cm, cl)
          zk_leader     = CM.find_zk_leader(cm, cl)
          zk            = zk_leader[:hostname]
          cdh_ver       = zk_leader[:cdh_ver]
          zk_port       = CM.zk_port(cm, cl, zk_leader)
          hbase_manager = ht4cdh(tool: 'hbase-manager', cdh_ver: cdh_ver)
          krb_enabled   = CM.hbase_kerberos_enabled?(cm, cl)
          yield [hbase_manager, zk, zk_port, krb_enabled]
        end

        # Generate a hbase-manager balancer command.
        def gen_hbase_manager_balancer_command(cm, cl, status)
          gen_hbase_manager_command(cm, cl) do |arr|
            opt = gen_krb_opt(cm) if arr[3]
            "java -jar #{HT_HOME}/#{arr[0]}" \
            " assign #{arr[1]}:#{arr[2]} balancer #{status} #{opt}" \
            ' | tail -1'
          end
        end

        # Generate a hbase-manager export command.
        def gen_hbase_manager_export_command(cm, cl, exp_file)
          gen_hbase_manager_command(cm, cl) do |arr|
            opt = gen_krb_opt(cm) if arr[3]
            "java -jar #{HT_HOME}/#{arr[0]}" \
            " assign #{arr[1]}:#{arr[2]} export #{exp_file} #{opt}"
          end
        end

        # Generate a hbase-manager empty command.
        def gen_hbase_manager_empty_command(cm, cl, rs, opt)
          gen_hbase_manager_command(cm, cl) do |arr|
            opt = "--skip-export #{opt}"
            opt += gen_krb_opt(cm) if arr[3]
            "java -jar #{HT_HOME}/#{arr[0]}" \
            " assign #{arr[1]}:#{arr[2]} empty #{rs} #{opt}"
          end
        end

        # Generate a hbase-manager import command.
        def gen_hbase_manager_import_command(cm, cl, exp_file, rs, opt)
          gen_hbase_manager_command(cm, cl) do |arr|
            opt += gen_krb_opt(cm) if arr[3]
            "java -jar #{HT_HOME}/#{arr[0]}" \
            " assign #{arr[1]}:#{arr[2]} import #{exp_file} --rs=#{rs} #{opt}"
          end
        end

        # Get Regionserver name from export file.
        def get_rs_from_exp_file(exp_file, hostname)
          result = File.readlines(exp_file).find do |line|
            line.split(',').first.split('.').first == hostname.split('.').first
          end
          result.split('/').first if result
        end


        # Run a hbase-manager balance command.
        def run_hbase_manager_balancer(cmd)
          Utils.run_cmd_capture3(cmd) do |err, _|
            raise CMUXHBaseToolBalancerError, "\n#{err}"
          end
        end

        # Run a hbase-manager export command.
        def run_hbase_manager_export(cmd)
          Utils.run_cmd_capture3(cmd) do |err, _|
            raise CMUXHBaseToolExportRSError, "\n#{err}"
          end
        end

        # Run a hbase-manager empty command.
        def run_hbase_manager_empty(cmd)
          Utils.run_cmd_capture3(cmd) do |err, _|
            raise CMUXHBaseToolEmptyRSError, "\n#{err}"
          end
        end

        # Run a hbase-manager import command.
        def run_hbase_manager_import(cmd)
          Utils.run_cmd_capture3(cmd) do |err, _|
            raise CMUXHBaseToolImportRSError, "\n#{err}"
          end
        end
      end
    end
  end
end
