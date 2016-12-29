class ContestsController < ApplicationController
  load_resource
  authorize_resource except: :update

  def admin
    grab_problems
    @feedback_questions = @contest.feedback_questions
    Ajat.info "admin|uid:#{current_user.id}|uname:#{current_user}|" \
    "contest_id:#{params[:contest_id]}"
  end

  def new; end

  def create
    if @contest.save
      Ajat.info "contest_created|id:#{@contest.id}"
      redirect_to contest_path(@contest), notice: "#{@contest} berhasil dibuat!"
    else
      Ajat.warn "contest_created_fail|#{@contest.errors.full_messages}"
      render 'new', alert: 'Kontes gagal dibuat!'
    end
  end

  def show
    if @contest.currently_in_contest?
      @user_contest = UserContest.find_by(contest: @contest, user: current_user)
      redirect_to new_contest_user_contest_path(@contest) if @user_contest.nil?
    elsif @contest.result_released || can?(:preview, @contest)
      @mask = false # agak gimanaaa gitu

      # This is a big query
      @user_contests = @contest.results(user: [:roles, :province])
      @same_province_ucs = @user_contests.select do |uc|
        uc.user.province_id == current_user.province_id
      end
      @user_contest = @user_contests.find_by('user_contests.user_id' =>
                                             current_user.id)

      # Keep medallists only
      @user_contests = @user_contests.where('marks.total_mark >= bronze_cutoff')
    end

    grab_submissions if @user_contest
    grab_problems
  end

  def index
    @contests = Contest.where('start_time < ?', Time.zone.now + 3.months)
    %w(short_problems long_problems user_contests).each do |table|
      subquery = Contest.count_sql(table)
      @contests = @contests.joins("INNER JOIN (#{subquery}) #{table} " \
                                  "ON contests.id = #{table}.id")
    end
    @contests = @contests.select('contests.*, ' \
                                 'short_problems.short_problems_count, ' \
                                 'long_problems.long_problems_count, ' \
                                 'user_contests.user_contests_count')
                         .order(start_time: :desc)
                         .paginate(page: params[:offset], per_page: 10)
  end

  def update
    if can? :update, @contest
      update_contest
    elsif can? :upload_ms, @contest
      update_marking_scheme
    else
      raise CanCan::AccessDenied.new('Cannot update', :update, @contest)
    end
    redirect_to contest_path(@contest)
  end

  def destroy
    @contest.destroy
    Ajat.warn "contest_destroyed|#{@contest}"
    redirect_to contests_path, notice: 'Kontes berhasil dihilangkan!'
  end

  def download_problem_pdf
    send_file @contest.problem_pdf.path
  rescue Errno::ENOENT
    redirect_to @contest, alert: 'File belum ada!'
  end

  def download_marking_scheme
    send_file @contest.marking_scheme.path
  rescue Errno::ENOENT
    redirect_to admin_contest_path(@contest), alert: 'File belum ada!'
  end

  def download_reports
    @contest.compress_reports
    send_file @contest.report_zip_location
  rescue Errno::ENOENT
    redirect_to admin_contest_path(@contest), alert: 'File belum ada!'
  end

  def read_problems
    t = TexReader.new(@contest, params[:answers].split(','),
                      params[:problem_tex])
    params[:compile_only] ? t.compile_tex : t.run
    redirect_to admin_contest_path(@contest), notice: 'TeX berhasil dibaca!'
  end

  def summary
    @scores = @contest.array_of_scores
    @count = @scores.inject(&:+)
    redirect_to contest_path(@contest), notice: 'Tidak ada data' if @count.zero?

    grab_problems
  end

  def download_results
    send_file @contest.results_location, disposition: :inline,
                                         filename: "Hasil #{@contest}.pdf"
  rescue ActionController::MissingFile
    @contest.refresh_results_pdf
    retry
  end

  def refresh
    @contest.refresh
    redirect_to admin_contest_path(@contest), notice: 'Refreshed!'
  end

  private

  def contest_params
    params.require(:contest).permit(:name, :start_time, :end_time, :result_time,
                                    :feedback_time, :problem_pdf, :gold_cutoff,
                                    :silver_cutoff, :bronze_cutoff,
                                    :result_released, :marking_scheme)
  end

  def marking_scheme_params
    params.require(:contest).permit(:marking_scheme)
  end

  def grab_problems
    @short_problems = @contest.short_problems.order('problem_no')
    @long_problems = @contest.long_problems.order('problem_no')
    @no_short_probs = @short_problems.empty?
  end

  def grab_submissions
    @short_submissions = @user_contest.short_submissions
    @long_submissions = @user_contest.long_submissions
  end

  def update_contest
    if @contest.update(contest_params)
      Ajat.info "contest_updated|id:#{@contest.id}"
      flash[:notice] = "#{@contest} berhasil diubah."
    else
      Ajat.warn "contest_update_fail|#{@contest.errors.full_messages}"
      flash[:alert] = "#{@contest} gagal diubah!"
    end
  end

  def update_marking_scheme
    if @contest.update(marking_scheme_params)
      Ajat.info "marking_scheme_uploaded|id:#{@contest.id}"
      flash[:notice] = "#{@contest} berhasil diubah."
    else
      Ajat.warn "marking_scheme_upload_fail|#{@contest.errors.full_messages}"
      flash[:alert] = "#{@contest} gagal diubah!"
    end
  end
end
