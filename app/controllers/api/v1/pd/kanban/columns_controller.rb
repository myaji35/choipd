module Api
  module V1
    module Pd
      module Kanban
        # GET/POST /api/v1/pd/kanban/columns
        # PATCH/DELETE /api/v1/pd/kanban/columns/:id
        class ColumnsController < Api::V1::BaseController
          def index
            scope = KanbanColumn.all
            if params[:project_id].present?
              scope = scope.where(kanban_project_id: params[:project_id])
            end
            render_success(columns: scope.ordered.map { |c| serialize(c) })
          end

          def create
            column = KanbanColumn.new(column_params)
            column.sort_order ||= (column.kanban_project&.kanban_columns&.maximum(:sort_order) || -1) + 1
            column.save!
            render_success({ column: serialize(column) }, status: :created)
          end

          def update
            column = KanbanColumn.find(params[:id])
            column.update!(column_params)
            render_success(column: serialize(column))
          end

          def destroy
            KanbanColumn.find(params[:id]).destroy!
            render_success(deleted: true)
          end

          private

          def column_params
            params.require(:column).permit(:title, :sort_order, :kanban_project_id)
          end

          def serialize(c)
            {
              id: c.id,
              title: c.title,
              sort_order: c.sort_order,
              kanban_project_id: c.kanban_project_id,
              created_at: c.created_at,
              updated_at: c.updated_at,
            }
          end
        end
      end
    end
  end
end
