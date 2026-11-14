env_file = Rails.root.join(".env")

if env_file.exist?
  env_file.each_line do |line|
    line = line.strip
    next if line.empty? || line.start_with?("#")

    key, value = line.split("=", 2)
    next if key.blank? || ENV.key?(key)

    ENV[key] = value.to_s
  end
end
