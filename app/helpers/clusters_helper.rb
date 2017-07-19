module ClustersHelper

  # Converts array of cluster instances to a hash keyed by cluster#type.
  #
  # @param [Array] clusters
  # @return [Hash]
  def cluster_groups(clusters)
    clusters.reduce({}) do
      # @type acc [Hash]
      # @type cluster [Cluster]
      |acc, cluster|

      value = acc[cluster.type] || (acc[cluster.type] = [])
      value.push(cluster)
      acc
    end
  end

  # Provides a table model for diplaying specific table based on cluster type
  # @param [String] cluster_type
  # @param [Array] clusters
  # @param [Block] block
  def cluster_table(cluster_type, clusters, &block)
    header_cols = case cluster_type
                    when 'AmazonCloud'
                      [{'Region' => 20}, {'Instance Type' => 20}, {'Access Key' => 30}, {'SSH Identity' => 20}]
                    when 'DataCenter'
                      [{'Title' => 30}, {'Hosts' => 20}, {'User' => 20}, {'SSH Identity' => 20}]
                    else
                      raise('Unknown cluster type')
                  end
    rows = clusters.map do
    # @type cluster [Cluster]
    |cluster|
      row_group = {}
      row = case cluster_type
        when 'AmazonCloud'
          [link_to(cluster.region_title, edit_project_amazon_cloud_path(@project, cluster, page: params[:page])),
           cluster.instance_type, cluster.access_key]
        when 'DataCenter'
          [link_to(cluster.title, edit_project_data_center_path(@project, cluster, page: params[:page])),
           cluster.machines, cluster.user_name]
      end

      ident_file_path = cluster.ssh_identity_file_name.blank? ? '' : link_to(cluster.ssh_identity_file_name, project_cluster_path(@project, cluster, format: :pem))
      row << ident_file_path
      row_group[:row] = row

      ag = TableModel::ActionGroup.new
      edit_link_args = case cluster.type
                         when 'AmazonCloud'
                           [edit_project_amazon_cloud_path(@project, cluster)]
                         when 'DataCenter'
                           [edit_project_data_center_path(@project, cluster)]
                         else
                           raise('Unknown cluster type')
                       end

      edit_link_args << {
          class: 'btn btn-primary'
      }
      ag.edit_link = link_to(*edit_link_args) { raw '<span class="glyphicon glyphicon-edit"></span>' }

      delete_link_args = case cluster.type
                           when 'AmazonCloud'
                             [project_amazon_cloud_path(@project, cluster)]
                           when 'DataCenter'
                             [project_data_center_path(@project, cluster)]
                           else
                             raise('Unknown cluster type')
                         end
      delete_link_args << {
          method: :delete,
          data: {
              confirm: 'This will delete this cluster from your configuration. Proceed to delete?',
              confirm_title: 'Warning',
              confirm_context: 'danger'
          },
          class: "btn text-danger#{cluster.can_delete? ? '' : ' disabled'}"
      }
      ag.delete_link = link_to(*delete_link_args) { raw '<span class="glyphicon glyphicon-trash"></span>' }

      row_group[:actions] = ag

      row_group
    end

    yield TableModel.new(header_cols, rows)
  end

  class TableModel

    def initialize(header_cols, rows)
      @header_cols = header_cols
      @rows = rows
    end

    def header(&block)
      yield Header.new(@header_cols)
    end

    def rows
      @rows.map { |row| Row.new(row) }
    end

    class Header
      def initialize(header_cols)
        @header_cols = header_cols.map { |cs| {title: cs.keys.first, width: cs.values.first} }
      end

      def cols
        @header_cols
      end
    end

    class Row
      def initialize(row)
        @row = row
      end

      def cols
        @row[:row]
      end

      def edit_link
        @row[:actions].edit_link
      end

      def delete_link
        @row[:actions].delete_link
      end
    end

    class ActionGroup
      attr_accessor :edit_link, :delete_link
    end

  end

  # @param [Array] ary
  # @return [String] array elements joined with a <br/> tag
  def to_list(ary)
    ary.map { |e| h(e) }.join('<br/>')
  end

  # Renders the appropriate form based on param[:type]
  # @param [Hash] options
  def form_for_cluster(options = {})
    view_part = case params[:type]
            when 'AmazonCloud'
              'clusters/amazon'
            when 'DataCenter'
              'clusters/data_center'
            else
              raise('Unknown cluster type')
          end
    render({partial: view_part}.merge(options))
  end

  # adds an Other option at the end
  # @param [Array] options
  def instance_types_with_other_option(options)
    options.map { |e| e}.push(OpenStruct.new(id: '', name: 'Other'))
  end

  # Disables access & secret key
  # @param [Cluster] cluster
  def disable_keys_fields?(cluster = @cluster)
    cluster.persisted? && cluster.errors[:access_key].empty? && cluster.errors[:secret_key].empty?
  end

  # a select or input based on conditions
  # @param [ActionView::Helpers::FormBuilder] form
  # @param [Cluster] cluster
  def instance_type_field(form, cluster = @cluster)
    # when instance_type is known, show drop down else a text field
    if cluster.instance_type.blank? or cluster.known_instance_type?
      concat(form.collection_select(:instance_type,
                                    instance_types_with_other_option(AmazonCloud.instance_types),
                                    :id, :name, {}, {:class => 'form-control'}))
      concat(form.text_field :instance_type, disabled: true, class: 'form-control hidden')
    else
      concat(form.text_field :instance_type, class: 'form-control')
    end

    nil
  end

end
