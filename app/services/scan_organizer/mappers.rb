module ScanOrganizer
  module Mappers
    FORBIDDEN_FILENAME_CHARACTERS = %r{[/\\:*?"<>|[:cntrl:]]}

    def self.contact(fields)
      fields = fields.stringify_keys
      {
        names: [ { unstructuredName: fields["name"] } ],
        organizations: [ { name: fields["company"], title: fields["title"] }.compact ],
        phoneNumbers: Array(fields["phones"]).filter_map { |phone| { value: phone } if phone.present? },
        emailAddresses: Array(fields["emails"]).filter_map { |email| { value: email } if email.present? },
        addresses: [ { streetAddress: fields["address"] } ]
      }.transform_values { |entries| entries.reject { |entry| entry.values.all?(&:blank?) } }
        .reject { |_, entries| entries.empty? }
    end

    def self.receipt_row(fields, original_name)
      fields = fields.stringify_keys
      [ fields["date"], fields["merchant"], fields["total"], fields["vat"], fields["payment_method"], original_name ]
    end

    def self.document_target(fields, original_name)
      fields = fields.stringify_keys
      date = begin
        Date.iso8601(fields["date"].to_s).iso8601
      rescue ArgumentError
        Date.current.iso8601
      end
      original_extension = File.extname(original_name.to_s)
      extension = original_extension.gsub(FORBIDDEN_FILENAME_CHARACTERS, "")[0, 68]
      title = clean_segment(fields["title"]).presence || clean_segment(File.basename(original_name.to_s, original_extension)).presence || "문서"
      doc_type = clean_segment(fields["doc_type"]).presence || "기타"
      stem = "#{date}_#{title}"[0, 80 - extension.length]
      { folder_path: "문서/#{doc_type}", new_name: "#{stem}#{extension}" }
    end

    def self.clean_segment(value)
      value.to_s.gsub(FORBIDDEN_FILENAME_CHARACTERS, "").squish.sub(/\A\.+\z/, "")
    end
    private_class_method :clean_segment
  end
end
