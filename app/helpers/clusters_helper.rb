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
                      raise('Should never happen?')
                  end
    rows = clusters.map do
    # @type cluster [Cluster]
    |cluster|
      row = case cluster_type
        when 'AmazonCloud'
          [cluster.region, cluster.instance_type, cluster.access_key]
        when 'DataCenter'
          [cluster.title, cluster.machines, cluster.user_name]
      end

      ident_file_path = cluster.ssh_identity_file_name.blank? ? '' : link_to(cluster.ssh_identity_file_name, project_cluster_path(@project, cluster, format: :pem))
      row << ident_file_path
      row << case cluster.type
               when 'AmazonCloud'
                 link_to 'Edit', edit_project_amazon_cloud_path(@project, cluster, page: params[:page])
               when 'DataCenter'
                 link_to 'Edit', edit_project_data_center_path(@project, cluster, page: params[:page])
               else
                 raise('should never happen?')
             end
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
        @row.slice(0..-2)
      end

      def edit_link
        @row.last
      end
    end
  end

  def to_list(ary)
    ary.map { |e| h(e) }.join('<br/>')
  end

  def form_for_cluster(options = {})
    view_part = case params[:type]
            when 'AmazonCloud'
              'clusters/amazon'
            when 'DataCenter'
              'clusters/data_center'
            else
              raise('should not happen?')
          end
    render({partial: view_part}.merge(options))
  end

end
