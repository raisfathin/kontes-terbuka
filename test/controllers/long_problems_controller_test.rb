require 'test_helper'

class LongProblemsControllerTest < ActionController::TestCase
  setup :login, :create_items
  setup do |action|
    unless %w(test_routes test_no_permissions).include? action.name
      promote(:admin)
    end
  end

  test 'routes' do
    assert_equal contest_long_problems_path(@c),
                 "/contests/#{@c.to_param}/long-problems"
    assert_equal edit_long_problem_path(@lp),
                 "/long-problems/#{@lp.id}/edit"
    assert_equal long_problem_path(@lp),
                 "/long-problems/#{@lp.id}"
    assert_equal destroy_on_contest_contest_long_problems_path(@c),
                 "/contests/#{@c.to_param}/long-problems/destroy-on-contest"
    assert_equal download_long_problem_path(@lp),
                 "/long-problems/#{@lp.id}/download"
    assert_equal autofill_long_problem_path(@lp),
                 "/long-problems/#{@lp.id}/autofill"
    assert_equal upload_report_long_problem_path(@lp),
                 "/long-problems/#{@lp.id}/upload-report"
    assert_equal start_mark_final_long_problem_path(@lp),
                 "/long-problems/#{@lp.id}/start-mark-final"
  end

  test 'no permissions' do
    assert_raise ActionController::RoutingError do
      post :create, contest_id: @c.id,
                    long_problem: { statement: 'Hello there', problem_no: 5 }
    end
  end

  test 'create' do
    post :create, contest_id: @c.id,
                  long_problem: { statement: 'Hello there', problem_no: 5 }
    assert_redirected_to admin_contest_path @c
    assert_equal @c.long_problems.where(statement: 'Hello there').count, 1
    assert_equal flash[:notice], 'Long Problem terbuat!'
  end

  test 'edit' do
    get :edit, id: @lp.id
    assert_response 200
  end

  test 'patch update' do
    patch :update, id: @lp.id, long_problem: { statement: 'asdf' }
    assert_redirected_to admin_contest_path @c
    assert_equal @lp.reload.statement, 'asdf'
  end

  test 'put update' do
    put :update, id: @lp.id, long_problem: { statement: 'asdf' }
    assert_redirected_to admin_contest_path @c
    assert_equal @lp.reload.statement, 'asdf'
  end

  test 'destroy' do
    delete :destroy, id: @lp.id
    assert_redirected_to admin_contest_path @c
    assert_nil LongProblem.find_by id: @lp.id
  end

  test 'download' do
    create(:long_submission, long_problem: @lp)
    get :download, id: @lp.id
    assert_response 200
    assert_equal @response.content_type, 'application/zip'
    assert @response.header['Content-Disposition'].include?(
      "filename=\"#{File.basename @lp.zip_location}\""
    )
    assert_equal IO.binread(@lp.zip_location), @response.body
  end

  test 'autofill' do
    ls = create_list(:long_submission, 5, long_problem: @lp)
    ls.each do |l|
      tm = create_list(:temporary_marking, 2, long_submission: l)
      tm.each { |t| t.update(mark: 2) }
    end

    patch :autofill, id: @lp.id

    assert_redirected_to long_problem_long_submissions_path @lp
    @lp.long_submissions.each { |l| assert_equal l.score, 2 }
    assert_equal flash[:notice], 'Sulap selesai!'
  end

  test 'start_mark_final' do
    patch :start_mark_final, id: @lp.id
    assert_redirected_to long_problem_long_submissions_path @lp
    assert @lp.reload.start_mark_final
    assert_equal flash[:notice], 'Langsung diskusi!'
  end

  test 'upload_report' do
    post :upload_report,
         id: @lp.id,
         long_problem: {
           report: Rack::Test::UploadedFile.new(File.path(PDF),
                                                'application/pdf')
         }
    assert_redirected_to long_problem_long_submissions_path @lp
    assert_equal flash[:notice], 'Laporan telah diupload!'
    assert @lp.reload.report.exists?
  end

  test 'destroy_on_contest' do
    create_list(:long_problem, 5, contest: @c)
    delete :destroy_on_contest, contest_id: @c.id
    assert_redirected_to admin_contest_path @c
    assert_equal flash[:notice], 'Bagian B hancur!'
    assert_equal @c.long_problems.count, 0
  end

  private

  def create_items
    @lp = create(:long_problem)
    @c = @lp.contest
  end
end
