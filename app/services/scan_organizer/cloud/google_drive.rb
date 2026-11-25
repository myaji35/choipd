module ScanOrganizer
  module Cloud
    class GoogleDrive
      SCOPES = %w[
        https://www.googleapis.com/auth/drive.file
        https://www.googleapis.com/auth/contacts
        https://www.googleapis.com/auth/spreadsheets
      ].freeze
      # drive.file은 앱이 만들거나 회원이 Picker로 선택한 파일에 접근합니다.
      # contacts와 spreadsheets는 각각 연락처 생성과 영수증 행 저장에 사용합니다.

      DRIVE_FILES_URL = "https://www.googleapis.com/drive/v3/files"
      PEOPLE_URL = "https://people.googleapis.com/v1/people:createContact"
      SHEETS_URL = "https://sheets.googleapis.com/v4/spreadsheets"
      TOKEN_URL = "https://oauth2.googleapis.com/token"
      FOLDER_TYPE = "application/vnd.google-apps.folder"
      SHEET_TYPE = "application/vnd.google-apps.spreadsheet"

      def initialize(refresh_token:, scan_folder_id: nil)
        @refresh_token = refresh_token
        @scan_folder_id = scan_folder_id
      end

      def inspect
        "#<#{self.class} scan_folder_id=#{@scan_folder_id.inspect}>"
      end

      def list_new_files(folder_id)
        files_in(folder_id, "mimeType contains 'image/'").map do |file|
          { id: file.fetch("id"), name: file.fetch("name"), mime_type: file.fetch("mimeType") }
        end
      end

      def download(file_id)
        request(Net::HTTP::Get, file_url(file_id), query: { alt: "media", supportsAllDrives: true })
      end

      def move_and_rename(file_id:, folder_path:, new_name:)
        file = drive_request(Net::HTTP::Get, file_url(file_id), query: { fields: "parents", supportsAllDrives: true })
        parent_id = folder_path.split("/").reduce(scan_folder_id!) do |parent, name|
          find_or_create(parent, name, FOLDER_TYPE)
        end
        old_parents = Array(file["parents"]) - [ parent_id ]
        query = { supportsAllDrives: true, fields: "webViewLink" }
        query[:addParents] = parent_id unless Array(file["parents"]).include?(parent_id)
        query[:removeParents] = old_parents.join(",") if old_parents.present?
        result = drive_request(Net::HTTP::Patch, file_url(file_id), query: query, json: { name: new_name })
        result["webViewLink"].presence || "#{folder_path}/#{new_name}"
      end

      def create_contact(fields)
        contact = Http.parse(request(Net::HTTP::Post, PEOPLE_URL, json: fields, query: { personFields: "names" }))
        contact.fetch("resourceName")
      end

      def append_receipt_row(row_array)
        sheet_id = find_or_create(scan_folder_id!, "영수증", SHEET_TYPE, app_properties: { scanOrganizer: "receipts" })
        result = Http.parse(request(Net::HTTP::Post, "#{SHEETS_URL}/#{encode(sheet_id)}/values/A:F:append",
          query: { valueInputOption: "RAW", insertDataOption: "INSERT_ROWS" }, json: { values: [ row_array ] }))
        "https://docs.google.com/spreadsheets/d/#{encode(sheet_id)}/edit#range=#{encode(result.fetch("updates").fetch("updatedRange"))}"
      end

      private

      def scan_folder_id!
        @scan_folder_id.presence || raise(Http::Error, "스캔 폴더 ID를 등록해 주세요.")
      end

      def files_in(parent, condition)
        files = []
        query = {
          q: "'#{drive_literal(parent)}' in parents and trashed = false and #{condition}",
          fields: "nextPageToken,files(id,name,mimeType)",
          pageSize: 100,
          supportsAllDrives: true,
          includeItemsFromAllDrives: true
        }
        loop do
          result = drive_request(Net::HTTP::Get, DRIVE_FILES_URL, query: query)
          files.concat(result.fetch("files", []))
          break if result["nextPageToken"].blank?

          query[:pageToken] = result["nextPageToken"]
        end
        files
      end

      def find_or_create(parent, name, mime_type, app_properties: {})
        condition = "name = '#{drive_literal(name)}' and mimeType = '#{mime_type}'"
        app_properties.each do |key, value|
          condition += " and appProperties has { key='#{drive_literal(key)}' and value='#{drive_literal(value)}' }"
        end
        existing = files_in(parent, condition).first
        return existing.fetch("id") if existing

        body = { name: name, mimeType: mime_type, parents: [ parent ] }
        body[:appProperties] = app_properties if app_properties.present?
        drive_request(Net::HTTP::Post, DRIVE_FILES_URL, query: { fields: "id", supportsAllDrives: true }, json: body).fetch("id")
      end

      def file_url(file_id)
        "#{DRIVE_FILES_URL}/#{encode(file_id)}"
      end

      def drive_literal(value)
        value.to_s.gsub(/[\\']/) { |character| "\\#{character}" }
      end

      def encode(value)
        URI.encode_www_form_component(value)
      end

      def drive_request(...)
        Http.parse(request(...))
      end

      def request(method, url, **options)
        Http.request(method, url, headers: { "Authorization" => "Bearer #{access_token}" }, **options)
      end

      def access_token
        return @access_token if @access_token.present? && Time.current < @token_expires_at
        raise Http::Error, "구글 드라이브 연결이 필요합니다." if @refresh_token.blank?

        token = Http.parse(Http.request(Net::HTTP::Post, TOKEN_URL, form: {
          client_id: ENV["GOOGLE_CLIENT_ID"],
          client_secret: ENV["GOOGLE_CLIENT_SECRET"],
          refresh_token: @refresh_token,
          grant_type: "refresh_token"
        }))
        @token_expires_at = Time.current + token.fetch("expires_in").to_i - 30.seconds
        @access_token = token.fetch("access_token")
      end
    end
  end
end
