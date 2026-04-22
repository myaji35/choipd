module Api
  module V1
    module Pd
      module Kanban
        # GET/POST/PATCH /api/v1/pd/kanban/tasks
        # DELETE /api/v1/pd/kanban/tasks/:id
        class TasksController < Api::V1::BaseController
          def index
            scope = KanbanTask.all
            scope = scope.where(kanban_column_id: params[:column_id]) if params[:column_id].present?
            scope = scope.where(project_id: params[:project_id]) if params[:project_id].present?
            scope = scope.by_priority(params[:priority]) if params[:priority].present?
            scope = scope.completed if params[:completed] == "true"
            scope = scope.open if params[:completed] == "false"
            render_success(tasks: scope.ordered.map { |t| serialize(t) })
          end

          def create
            task = KanbanTask.new(task_params)
            task.sort_order ||= (task.kanban_column&.kanban_tasks&.maximum(:sort_order) || -1) + 1
            task.save!
            render_success({ task: serialize(task) }, status: :created)
          end

          def update
            task = KanbanTask.find(params[:id])
            if params.dig(:task, :complete) == true
              task.complete!
            elsif params.dig(:task, :complete) == false
              task.reopen!
            else
              task.update!(task_params)
            end
            render_success(task: serialize(task))
          end

          def destroy
            KanbanTask.find(params[:id]).destroy!
            render_success(deleted: true)
          end

          private

          def task_params
            permitted = params.require(:task).permit(
              :title, :description, :priority, :due_date,
              :is_completed, :sort_order, :kanban_column_id, :project_id,
              labels: [],
            )
            if permitted[:labels].is_a?(Array)
              permitted[:labels] = permitted[:labels].to_json
            end
            permitted
          end

          def serialize(t)
            {
              id: t.id,
              title: t.title,
              description: t.description,
              priority: t.priority,
              labels: t.labels_array,
              due_date: t.due_date,
              is_completed: t.is_completed,
              completed_at: t.completed_at,
              sort_order: t.sort_order,
              kanban_column_id: t.kanban_column_id,
              project_id: t.project_id,
              created_at: t.created_at,
              updated_at: t.updated_at,
            }
          end
        end
      end
    end
  end
end
