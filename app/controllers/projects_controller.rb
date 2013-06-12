# Copyright 2013 Square Inc.
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.

# Controller for working with {Project Projects}.

class ProjectsController < ApplicationController
  before_filter :authenticate_user!
  before_filter :monitor_required, only: [:new, :create, :edit, :update]
  before_filter :find_project, except: [:index, :new, :create]

  before_filter(only: [:create, :update]) do
    fix_empty_arrays [:project, :key_exclusions],
                     [:project, :key_inclusions],
                     [:project, :skip_paths],
                     [:project, :only_paths],
                     [:project, :cache_manifest_formats],
                     [:project, :watched_branches]
    fix_empty_hashes [:project, :key_locale_exclusions],
                     [:project, :key_locale_inclusions],
                     [:project, :only_importer_paths],
                     [:project, :skip_importer_paths],
                     reject_blank_value_elements: true
    fix_empty_hashes [:project, :targeted_rfc5646_locales],
                     map_values: ->(req) { req.parse_bool }
  end

  respond_to :html, except: [:index, :show]
  respond_to :json, only: [:index, :show]

  # Returns a list of Projects.
  #
  # Routes
  # ------
  #
  # * `GET /projects`

  def index
    respond_to do |format|
      format.json do
        @projects = Project.order('created_at DESC').limit(25)
        if params[:offset].to_i > 0
          @projects = @projects.offset(params[:offset].to_i)
        end
        render json: decorate(@projects).to_json
      end
    end
  end

  # Returns information about a Project.
  #
  # Routes
  # ------
  #
  # * `GET /projects/:id`
  #
  # Path Parameters
  # ---------------
  #
  # |      |                   |
  # |:-----|:------------------|
  # | `id` | A Project's slug. |

  def show
    respond_with @project do |format|
      format.json do
        render json: @project.as_json.merge(
                         commits_url: project_commits_url(@project, format: 'json'),
                         commits:     @project.commits.order('committed_at DESC').limit(10).map { |commit|
                           commit.as_json.merge(
                               percent_done:       commit.fraction_done.nan? ? 0.0 : commit.fraction_done*100,
                               translations_done:  commit.translations_done,
                               translations_total: commit.translations_total,
                               strings_total:      commit.strings_total,
                               import_url:         import_project_commit_url(@project, commit, format: 'json'),
                               sync_url:           sync_project_commit_url(@project, commit, format: 'json'),
                               redo_url:           redo_project_commit_url(@project, commit, format: 'json'),
                               url:                project_commit_url(@project, commit),
                               status_url:         project_commit_url(@project, commit),
                           )
                         }
                     )
      end
    end
  end

  # Displays a form where an admin can add a new Project.
  #
  # Routes
  # ------
  #
  # * `GET /projects/new`

  def new
    @project ||= Project.new
    respond_with @project
  end

  # Creates a new Project.
  #
  # Routes
  # ------
  #
  # * `POST /projects`
  #
  # Body Parameters
  # ---------------
  #
  # |           |                                            |
  # |:----------|--------------------------------------------|
  # | `project` | Parameterized hash of Project information. |

  def create
    @project = Project.create(params[:project], as: :user)
    respond_with @project, location: administrators_url
  end

  # Displays a form where an admin can edit a Project.
  #
  # Routes
  # ------
  #
  # * `GET /projects/:id/edit`
  #
  # Path Parameters
  # ---------------
  #
  # |      |                   |
  # |:-----|:------------------|
  # | `id` | A Project's slug. |

  def edit
    respond_with @project
  end

  # Updates a Project with new information.
  #
  # Routes
  # ------
  #
  # * `PUT /projects/:id`
  #
  # Path Parameters
  # ---------------
  #
  # |      |                   |
  # |:-----|:------------------|
  # | `id` | A Project's slug. |
  #
  # Body Parameters
  # ---------------
  #
  # |           |                                            |
  # |:----------|--------------------------------------------|
  # | `project` | Parameterized hash of Project information. |

  def update
    @project.update_attributes params[:project], as: :user
    respond_with @project, location: administrators_url
  end


  private

  def find_project
    @project = Project.find_from_slug!(params[:id])
  end

  def decorate(projects)
    projects.map do |project|
      project.as_json.merge(
          url:         project_url(project),
          commits_url: project_commits_url(project, format: 'json'),
          edit_url:    edit_project_url(project)
      )
    end
  end
end