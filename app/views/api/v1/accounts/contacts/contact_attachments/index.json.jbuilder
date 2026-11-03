json.meta do
  json.total_count @attachments.size
end

json.payload @attachments do |attachment|
  json.id attachment.id
  json.contact_id attachment.contact_id
  json.filename attachment.file.filename.to_s
  json.extension attachment.extension
  json.content_type attachment.file.content_type
  json.file_type attachment.image? ? 'image' : 'file'
  json.data_url attachment.file_url
  json.thumb_url attachment.thumb_url
  json.file_size attachment.file.byte_size
  json.created_at attachment.created_at.to_i
end
