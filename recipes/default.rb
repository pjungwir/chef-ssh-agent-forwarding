g = node['ssh_agent_forwarding']['deploy_group']

group g do
  # No app-specific user yet, but you can add it later once it exists:
  members ["root", node['current_user']]
end

ruby_block 'remember-auth-sock' do
  # Some of this code borrowed from root_ssh_agent cookbook:
  block do
    agents = {}
    ppid = Process.ppid
    Dir.glob('/tmp/ssh*/agent*').each do |fn|
      agents[fn.match(/agent\.(\d+)$/)[1]] = fn
    end
    while ppid != '1'
      if (agent = agents[ppid])
        node.default['ssh_agent_forwarding']['auth_sock'] = ENV['SSH_AUTH_SOCK'] = agent
        break
      end
      File.open("/proc/#{ppid}/status", "r") do |file|
        ppid = file.read().match(/PPid:\s+(\d+)/)[1]
      end
    end
    fail "Could not find running ssh agent. Is config.ssh.forward_agent enabled in Vagrantfile or ForwardAgent in ~/.ssh/config?" unless ENV['SSH_AUTH_SOCK']
  end
end

template node['ssh_agent_forwarding']['ssh_wrapper'] do
  source 'wrap-ssh4git.sh.erb'
  owner 'root'
  group g
  mode '755'
end

bash 'update-rights-for-forwarding' do
  code <<-EOF
    set -e
    chgrp root $SSH_AUTH_SOCK
    chgrp root `dirname $SSH_AUTH_SOCK`
    chmod 770 $SSH_AUTH_SOCK
    chmod 770 `dirname $SSH_AUTH_SOCK`
  EOF
  only_if { File.exists?(node['ssh_agent_forwarding']['auth_sock']) }
end

