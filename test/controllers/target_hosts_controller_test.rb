require 'test_helper'

class TargetHostsControllerTest < ActionController::TestCase
  setup do
    @target_host = target_hosts(:one)
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:target_hosts)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create target_host" do
    assert_difference('TargetHost.count') do
      post :create, target_host: { executable_path: @target_host.executable_path, executable_pid: @target_host.executable_pid, host_name: @target_host.host_name, project_id: @target_host.project_id, role_name: @target_host.role_name, sampling_interval: @target_host.sampling_interval, type: @target_host.type, user_name: @target_host.user_name }
    end

    assert_redirected_to target_host_path(assigns(:target_host))
  end

  test "should show target_host" do
    get :show, id: @target_host
    assert_response :success
  end

  test "should get edit" do
    get :edit, id: @target_host
    assert_response :success
  end

  test "should update target_host" do
    patch :update, id: @target_host, target_host: { executable_path: @target_host.executable_path, executable_pid: @target_host.executable_pid, host_name: @target_host.host_name, project_id: @target_host.project_id, role_name: @target_host.role_name, sampling_interval: @target_host.sampling_interval, type: @target_host.type, user_name: @target_host.user_name }
    assert_redirected_to target_host_path(assigns(:target_host))
  end

  test "should destroy target_host" do
    assert_difference('TargetHost.count', -1) do
      delete :destroy, id: @target_host
    end

    assert_redirected_to target_hosts_path
  end
end
