require "rake/clean"
require_relative "./wait_for.rb"
import "../rakefiles/kops.rake"

desc "Configure kubectl to know about cluster"
task :configure_kubectl => [@tmpdir, :configure_kops] do
  sh "kops export kubecfg #{ENV["TF_VAR_cluster_name"]}"
end

desc "Wait until cluster has converged and is ready to receive components"
task :wait_for_cluster_up => :configure_kubectl do
  puts "Waiting for Kubernetes cluster to be fully up..."
  puts "(You can Ctrl-C out of this safely. You may need to run :destroy afterward.)"

  wait_for("kops validate cluster --name #{ENV["TF_VAR_cluster_name"]}")
end

desc "Wait until cluster has undeployed components and is ready to shut down"
task :wait_for_cluster_down do
  # External-facing Services create ELBs, which will prevent terraform from
  # destroying resources later. Before we delete the Deployments associated
  # with the Service, give the Service time to shut down.
  #
  # Here's the best way I could figure to do that:
  # * Get a list of the names of all ELBs
  # * For each ELB, get the value of the "KubernetesCluster" Tag
  # * Make sure $TF_VAR_cluster_name doesn't appear in the list
  puts "Waiting for load balancers to be fully down..."
  puts "(You can Ctrl-C out of this safely. You may need to re-run :undeploy and/or :destroy afterward.)"
  wait_for("\
    elbs=$(aws elb describe-load-balancers \
      --region us-east-2 \
      --query LoadBalancerDescriptions[*].LoadBalancerName \
      --output text \
    ) && \
    tags=$(for elb in $elbs ; do \
      aws elb describe-tags \
      --region us-east-2 \
      --load-balancer-names $elb | jq -r \
      '.TagDescriptions[].Tags[] | select(.Key==\"KubernetesCluster\") | .Value' \
      ; done \
    ) && \
    [ \"$(echo $tags | grep \"#{ENV["TF_VAR_cluster_name"]}\")\" == \"\" ] \
  ")
end

task :find_gpii_components do
  @gpii_components = FileList.new("../modules/deploy/[0-9]*.yml").sort
end

desc "Deploy GPII components to cluster"
task :deploy => [:apply, :configure_kubectl, :wait_for_cluster_up, :find_gpii_components] do
  extra_components = [
    "https://raw.githubusercontent.com/kubernetes/kops/master/addons/kubernetes-dashboard/v1.5.0.yaml",
  ]
  components = extra_components + @gpii_components
  components.each do |component|
    sh "kubectl apply -f #{component}"
  end
end

# Shut things down via kubernetes, otherwise terraform destroy will get stuck
# on left-behind resources, e.g. ELBs and IGs.
desc "Delete GPII components from cluster"
task :undeploy => [:configure_kubectl, :find_gpii_components] do
  # Don't delete dashboard. It doesn't impede anything and it can be useful
  # even in an "undeployed" cluster.
  @gpii_components.reverse.each do |component|
    # Allow deletes to fail, e.g. to clean up a cluster that never got fully deployed.
    sh "kubectl delete -f #{component} --ignore-not-found"
  end
  Rake::Task["wait_for_cluster_down"].invoke
end
