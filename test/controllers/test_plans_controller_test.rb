require 'test_helper'

class TestPlansControllerTest < ActionController::TestCase
  setup do
    @test_plan = test_plans(:one)
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:test_plans)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create test_plan" do
    assert_difference('TestPlan.count') do
      post :create, test_plan: { default: @test_plan.default, project_id: @test_plan.project_id, status: @test_plan.status }
    end

    assert_redirected_to test_plan_path(assigns(:test_plan))
  end

  test "should show test_plan" do
    get :show, id: @test_plan
    assert_response :success
  end

  test "should get edit" do
    get :edit, id: @test_plan
    assert_response :success
  end

  test "should update test_plan" do
    patch :update, id: @test_plan, test_plan: { default: @test_plan.default, project_id: @test_plan.project_id, status: @test_plan.status }
    assert_redirected_to test_plan_path(assigns(:test_plan))
  end

  test "should destroy test_plan" do
    assert_difference('TestPlan.count', -1) do
      delete :destroy, id: @test_plan
    end

    assert_redirected_to test_plans_path
  end
end
