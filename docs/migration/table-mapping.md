# Next.js → Rails 테이블 매핑 명세서

**총 109 테이블 (17 도메인)** — 기존 Rails 모델 21개, 신규 작성 88개

| 표기 | 의미 |
|---|---|
| ✅ | Rails에 이미 존재 (검증/보강 필요) |
| 🆕 | 신규 작성 필요 |
| Phase | 변환 시점 |

## Phase 1 — P0 핵심 (18 테이블, 3 도메인)

### content (9)
| Next.js | Rails 모델 | 테이블명(snake) | 상태 |
|---|---|---|---|
| courses | Course | courses | ✅ |
| enrollments | Enrollment | enrollments | 🆕 |
| posts | Post | posts | ✅ |
| works | Work | works | ✅ |
| inquiries | Inquiry | inquiries | ✅ |
| leads | Lead | leads | ✅ |
| settings | Setting | settings | ✅ |
| adminUsers | AdminUser | admin_users | ✅ |
| heroImages | HeroImage | hero_images | ✅ |

### distribution (6)
| Next.js | Rails 모델 | 테이블명 | 상태 |
|---|---|---|---|
| distributors | Distributor | distributors | ✅ |
| distributorActivityLog | DistributorActivityLog | distributor_activity_logs | ✅ (단수→복수) |
| distributorResources | DistributorResource | distributor_resources | ✅ |
| subscriptionPlans | SubscriptionPlan | subscription_plans | ✅ |
| payments | Payment | payments | ✅ |
| invoices | Invoice | invoices | ✅ |

### sns (3)
| Next.js | Rails 모델 | 테이블명 | 상태 |
|---|---|---|---|
| snsAccounts | SnsAccount | sns_accounts | ✅ |
| snsScheduledPosts | SnsScheduledPost | sns_scheduled_posts | ✅ |
| snsPostHistory | SnsPostHistory | sns_post_histories | ✅ (단수→복수) |

## Phase 2 — P1 비즈니스 (27 테이블, 4 도메인)

### kanban (4)
| Next.js | Rails 모델 | 테이블명 | 상태 |
|---|---|---|---|
| kanbanProjects | KanbanProject | kanban_projects | ✅ |
| kanbanColumns | KanbanColumn | kanban_columns | ✅ |
| kanbanTasks | KanbanTask | kanban_tasks | ✅ |
| notifications | Notification | notifications | 🆕 |

### member (7)
| Next.js | Rails 모델 | 테이블명 | 상태 |
|---|---|---|---|
| members | Member | members | 🆕 |
| memberPortfolioItems | MemberPortfolioItem | member_portfolio_items | 🆕 |
| memberServices | MemberService | member_services | 🆕 |
| memberPosts | MemberPost | member_posts | 🆕 |
| memberInquiries | MemberInquiry | member_inquiries | 🆕 |
| memberReviews | MemberReview | member_reviews | 🆕 |
| memberBookings | MemberBooking | member_bookings | 🆕 |

### security (8)
| Next.js | Rails 모델 | 테이블명 | 상태 |
|---|---|---|---|
| auditLogs | AuditLog | audit_logs | 🆕 |
| securityEvents | SecurityEvent | security_events | 🆕 |
| dataDeletionRequests | DataDeletionRequest | data_deletion_requests | 🆕 |
| ipAccessControl | IpAccessControl | ip_access_controls | 🆕 (단수→복수) |
| twoFactorAuth | TwoFactorAuth | two_factor_auths | 🆕 (단수→복수) |
| loginAttempts | LoginAttempt | login_attempts | 🆕 |
| sessions | Session | sessions | 🆕 (Devise sessions와 충돌 — 별도 테이블명 검토) |
| passwordHistory | PasswordHistory | password_histories | 🆕 (단수→복수) |

### analytics (8)
| Next.js | Rails 모델 | 테이블명 | 상태 |
|---|---|---|---|
| analyticsEvents | AnalyticsEvent | analytics_events | 🆕 |
| cohorts | Cohort | cohorts | 🆕 |
| cohortUsers | CohortUser | cohort_users | 🆕 |
| abTests | AbTest | ab_tests | 🆕 |
| abTestParticipants | AbTestParticipant | ab_test_participants | 🆕 |
| customReports | CustomReport | custom_reports | 🆕 |
| funnels | Funnel | funnels | 🆕 |
| rfmSegments | RfmSegment | rfm_segments | 🆕 |

## Phase 3 — P2 고급 (31 테이블, 4 도메인)

### ai (8)
| Next.js | Rails 모델 | 테이블명 | 상태 |
|---|---|---|---|
| aiRecommendations | AiRecommendation | ai_recommendations | 🆕 |
| contentEmbeddings | ContentEmbedding | content_embeddings | 🆕 |
| chatbotConversations | ChatbotConversation | chatbot_conversations | 🆕 |
| aiGeneratedContent | AiGeneratedContent | ai_generated_contents | 🆕 (단수→복수) |
| contentQualityScores | ContentQualityScore | content_quality_scores | 🆕 |
| imageAutoTags | ImageAutoTag | image_auto_tags | 🆕 |
| faqKnowledgeBase | FaqKnowledgeBase | faq_knowledge_bases | 🆕 (단수→복수) |
| userActivityPatterns | UserActivityPattern | user_activity_patterns | 🆕 |

### automation (6)
| Next.js | Rails 모델 | 테이블명 | 상태 |
|---|---|---|---|
| workflows | Workflow | workflows | 🆕 |
| workflowExecutions | WorkflowExecution | workflow_executions | 🆕 |
| integrations | Integration | integrations | 🆕 |
| webhooks | Webhook | webhooks | 🆕 |
| webhookLogs | WebhookLog | webhook_logs | 🆕 |
| automationTemplates | AutomationTemplate | automation_templates | 🆕 |

### video (8)
| Next.js | Rails 모델 | 테이블명 | 상태 |
|---|---|---|---|
| videos | Video | videos | 🆕 |
| videoChapters | VideoChapter | video_chapters | 🆕 |
| videoSubtitles | VideoSubtitle | video_subtitles | 🆕 |
| watchHistory | WatchHistory | watch_histories | 🆕 (단수→복수) |
| liveStreams | LiveStream | live_streams | 🆕 |
| videoComments | VideoComment | video_comments | 🆕 |
| videoPlaylists | VideoPlaylist | video_playlists | 🆕 |
| playlistVideos | PlaylistVideo | playlist_videos | 🆕 |

### enterprise (9)
| Next.js | Rails 모델 | 테이블명 | 상태 |
|---|---|---|---|
| organizations | Organization | organizations | 🆕 |
| organizationBranding | OrganizationBranding | organization_brandings | 🆕 (단수→복수) |
| teams | Team | teams | 🆕 |
| organizationMembers | OrganizationMember | organization_members | 🆕 |
| ssoConfigurations | SsoConfiguration | sso_configurations | 🆕 |
| supportTickets | SupportTicket | support_tickets | 🆕 |
| supportTicketComments | SupportTicketComment | support_ticket_comments | 🆕 |
| slaMetrics | SlaMetric | sla_metrics | 🆕 |
| userBulkImportLogs | UserBulkImportLog | user_bulk_import_logs | 🆕 |

## Phase 4 — P3 부가 (23 테이블, 5 도메인)

### chat (6)
| Next.js | Rails 모델 | 테이블명 | 상태 |
|---|---|---|---|
| chatConversations | ChatConversation | chat_conversations | 🆕 |
| chatMessages | ChatMessage | chat_messages | 🆕 |
| memberMemories | MemberMemory | member_memories | 🆕 |
| memberUploads | MemberUpload | member_uploads | 🆕 |
| enrichmentCache | EnrichmentCache | enrichment_caches | 🆕 (단수→복수) |
| enrichmentLog | EnrichmentLog | enrichment_logs | 🆕 (단수→복수) |

### follower (5)
| Next.js | Rails 모델 | 테이블명 | 상태 |
|---|---|---|---|
| memberFollowers | MemberFollower | member_followers | 🆕 |
| memberAwards | MemberAward | member_awards | 🆕 |
| memberChannels | MemberChannel | member_channels | 🆕 |
| memberActivityTimeline | MemberActivityTimeline | member_activity_timelines | 🆕 (단수→복수) |
| memberProfileMedia | MemberProfileMedia | member_profile_medias | 🆕 (단수→복수) |

### pomelli (4)
| Next.js | Rails 모델 | 테이블명 | 상태 |
|---|---|---|---|
| personalDna | PersonalDna | personal_dnas | 🆕 (단수→복수) |
| profileThemes | ProfileTheme | profile_themes | 🆕 |
| profilePages | ProfilePage | profile_pages | 🆕 |
| profileSections | ProfileSection | profile_sections | 🆕 |

### talent (4)
| Next.js | Rails 모델 | 테이블명 | 상태 |
|---|---|---|---|
| skills | Skill | skills | 🆕 |
| memberSkills | MemberSkill | member_skills | 🆕 |
| memberDocuments | MemberDocument | member_documents | 🆕 |
| memberGapReports | MemberGapReport | member_gap_reports | 🆕 |

### tenant (4)
| Next.js | Rails 모델 | 테이블명 | 상태 |
|---|---|---|---|
| tenants | Tenant | tenants | 🆕 |
| tenantMembers | TenantMember | tenant_members | 🆕 |
| saasSubscriptions | SaasSubscription | saas_subscriptions | 🆕 |
| saasInvoices | SaasInvoice | saas_invoices | 🆕 |

## 요약 통계

| Phase | 도메인 | 테이블 | 신규 |
|---|---|---|---|
| 1 (P0) | 3 | 18 | 1 |
| 2 (P1) | 4 | 27 | 27 |
| 3 (P2) | 4 | 31 | 31 |
| 4 (P3) | 5 | 23 | 23 |
| **합계** | **16** | **99** | **82** |

> 💡 위 109가 99로 줄어든 이유: ApplicationRecord 등 추상 클래스 제외, 일부 테이블이 schema.ts에서 helper 함수로 변형되어 정확한 개수는 다시 검증 필요

## 변환 시 주의사항

### Rails 명명 컨벤션 차이
1. **Drizzle은 단수형 허용**, Rails는 **복수형 강제** (예: `password_history` → `password_histories`)
2. **Drizzle은 camelCase 컬럼**, Rails는 **snake_case** (예: `createdAt` → `created_at`)
3. **Sessions 테이블 충돌**: Devise/Rails 기본 sessions과 보안 도메인 sessions 충돌 → `user_sessions`로 rename 검토

### 컬럼 데이터 타입 매핑
| Drizzle SQLite | Rails Migration |
|---|---|
| `text()` | `string` (≤255) / `text` (그 이상) |
| `integer()` | `integer` |
| `integer({ mode: 'boolean' })` | `boolean` |
| `integer({ mode: 'timestamp' })` | `datetime` |
| `text({ mode: 'json' })` | `json` (SQLite 3.38+) |
| `real()` | `float` |
| `blob()` | `binary` |

### Foreign Key & Association
- Drizzle `references(() => users.id)` → Rails `belongs_to :user, foreign_key: :user_id`
- 양방향 관계는 Rails 측에서 `has_many`/`has_one` 추가
- `cascade: true` 옵션은 `dependent: :destroy`로 변환

### Validation
- Drizzle은 DB 레벨 제약만 — Rails ActiveModel validation을 별도로 추가 (`validates :email, presence: true, uniqueness: true`)
- Zod 스키마 (`src/lib/validations/`)에서 비즈니스 룰 추출 → Rails 모델로 이전
