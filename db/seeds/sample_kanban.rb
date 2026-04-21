# 샘플 칸반 보드 (Next.js에 데이터 없으므로 데모용 생성)
puts "📋 샘플 칸반 데이터"

return if KanbanProject.exists?

p = KanbanProject.create!(
  tenant_id: 1,
  title: "imPD Rails 변환 작업",
  description: "Next.js → Rails 도메인별 정직 변환",
  color: "#ff4d1c",
  icon: "folder"
)

cols = [
  { title: "할 일", color: "#94a3b8" },
  { title: "진행 중", color: "#3b82f6" },
  { title: "완료", color: "#10b981" }
].map.with_index { |c, i|
  p.kanban_columns.create!(tenant_id: 1, title: c[:title], color: c[:color], sort_order: i)
}

samples = [
  { col: 0, title: "kanban 도메인 변환", priority: "high", description: "Next.js 칸반 → Rails Stimulus 보드" },
  { col: 0, title: "content CMS 보강", priority: "medium" },
  { col: 0, title: "analytics 대시보드", priority: "low" },
  { col: 1, title: "members + talent 변환", priority: "high", description: "✓ 진행 중", assignee: "Claude" },
  { col: 2, title: "분양사 도메인 (D5A)", priority: "high", description: "Identity uploader + preview", assignee: "Claude", is_completed: true, completed_at: Time.current }
]
samples.each_with_index do |s, idx|
  cols[s[:col]].kanban_tasks.create!(
    tenant_id: 1,
    project_id: p.id,
    title: s[:title],
    description: s[:description],
    priority: s[:priority],
    assignee: s[:assignee],
    is_completed: s[:is_completed] || false,
    completed_at: s[:completed_at],
    sort_order: idx
  )
end
puts "  ✓ Project 1 + Columns 3 + Tasks 5 생성"
