require 'mail'
# email = 'energysparksamr@gmail.com'
email = 'energysparks@outlook.com'
pw = 'amr!amr!amr!'

# ruby mail gem not compatible with Ruby 2.5: https://github.com/mikel/mail/issues/1209
# changed pop3.rb:76 from 
#   new_message = Mail.new(mail.pop)
# to
#   new_message = Mail.new(mail.pop(''.dup)) 
# and pop2.rb:84 from
#   emails << Mail.new(mail.pop)
# to
#   emails << Mail.new(mail.pop(''.dup)) 
#

Mail.defaults do
  retriever_method :pop3, :address    => "outlook.office365.com",
                          :port       => 995,
                          :user_name  => email,
                          :password   => pw,
                          :enable_ssl => true
end

puts Mail.all.inspect

Mail.all.each do |mail|
  puts mail.subject

  mail.attachments.each do | attachment |
    filename = attachment.filename
    
    # Attachments is an AttachmentsList object containing a
    # number of Part objects
    if (attachment.content_type.start_with?('image/'))
      # extracting images for example...
      filename = attachment.filename
      begin
        File.open(images_dir + filename, "w+b", 0644) {|f| f.write attachment.decoded}
      rescue => e
        puts "Unable to save data for #{filename} because #{e.message}"
      end
    end
  end

end
