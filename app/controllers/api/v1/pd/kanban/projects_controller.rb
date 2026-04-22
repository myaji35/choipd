module Api
  module V1
    module Pd
      module Kanban
        # GET/POST /api/v1/pd/kanban/projects
        class ProjectsController < Api::V1::BaseController
          def index
            projects = KanbanProject.for_tenant.active.sorted
            render_success(projects: projects.map { |p| serialize(p) })
          end

          def create
            project = KanbanProject.new(project_params.merge(tenant_id: 1))
            project.save!
            render_success({ project: serialize(project) }, status: :created)
          end

          def show
            project = KanbanProject.for_tenant.find(params[:id])
            columns = project.kanban_columns.ordered.includes(:kanban_tasks)
            render_success(
              project: serialize(project),
              columns: columns.map { |c| serialize_column(c) },
            )
          end

          def update
            project = KanbanProject.for_tenant.find(params[:id])
            project.update!(project_params)
            render_success(project: serialize(project))
          end

          def destroy
            project = KanbanProject.for_tenant.find(params[:id])
            project.destroy!
            render_success(deleted: true)
          end

          private

          def project_params
            params.require(:project).permit(:title, :description, :color, :sort_order, :is_archived)
          end

          def serialize(p)
            {
              id: p.id,
              title: p.title,
              description: p.description,
              color: p.color,
              sort_order: p.sort_order,
              is_archived: p.is_archived,
              created_at: p.created_at,
              updated_at: p.updated_at,
            }
          end

          def serialize_column(c)
            {
              id: c.id,
              title: c.title,
              sort_order: c.sort_order,
              kanban_project_id: c.kanban_project_id,
              tasks: c.kanban_tasks.ordered.map { |t| serialize_task(t) },
            }
          end

          def serialize_task(t)
            {
              id: t.id,
              title: t.title,
              description: t.description,
              priority: t.priority,
              labels: t.labels_array,
              due_date: t.due_date,
              is_completed: t.is_completed,
              sort_order: t.sort_order,
              kanban_column_id: t.kanban_column_id,
            }
          end
        end
      end
    end
  end
end
