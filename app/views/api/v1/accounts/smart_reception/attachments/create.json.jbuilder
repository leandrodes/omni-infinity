json.payload do
  json.id @attachment.id
  json.keywords @attachment.keywords
  json.caption @attachment.caption
  json.filename @attachment.file.filename.to_s
  json.file_size @attachment.file.byte_size
  json.file_type @attachment.file.content_type
  json.data_url @attachment.file_url
end
