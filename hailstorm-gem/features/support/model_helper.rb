# frozen_string_literal: true

# Model Helper
module ModelHelper

  # @return [Hailstorm::Model::Project]
  def find_project(project_code)
    Hailstorm::Model::Project.where(project_code: project_code).first_or_create!
  end

  # @param [Hailstorm::Model::Project] project
  # @param [Hash] attributes
  # @return [Hailstorm::Model::AmazonCloud]
  def create_aws_cluster(project, attributes = {})
    require 'hailstorm/model/amazon_cloud'

    aws = Hailstorm::Model::AmazonCloud.where(attributes.merge(project_id: project.id)).first_or_create!(active: false)
    aws.update_column(:active, true) unless aws.active
    Hailstorm::Model::Cluster.where(project_id: project.id, cluster_type: aws.class.name, clusterable_id: aws.id)
                             .first_or_create!
    aws
  end

  # @param [Hailstorm::Model::AmazonCloud] aws
  # @param [Aws::EC2::Instance] ec2_instance
  def create_load_agent(aws, ec2_instance)
    jmeter_plan = Hailstorm::Model::JmeterPlan.where(project_id: aws.project.id,
                                                     test_plan_name: 'hailstorm-site-basic',
                                                     content_hash: 'A',
                                                     properties: '{}').first_or_create!(active: false)
    jmeter_plan.update_column(:active, true) unless jmeter_plan.active?

    require 'hailstorm/model/master_agent'
    master_agent = Hailstorm::Model::MasterAgent.where(clusterable_id: aws.id,
                                                       clusterable_type: aws.class.name,
                                                       jmeter_plan_id: jmeter_plan.id,
                                                       identifier: ec2_instance.id).first_or_create!(active: false)
    master_agent.update_column(:active, true) unless master_agent.active?
  end
end

World(ModelHelper)
