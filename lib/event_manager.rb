require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'date'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5,"0")[0..4]
end

def clean_phone_number(number)
  phone_number = number.gsub(/\D/, "")
  if phone_number.length == 10
    phone_number
  elsif phone_number.length < 10 || phone_number.length > 11
    'Incorrect number'
  elsif (phone_number.length == 11) && (phone_number[0] == "1")
    phone_number[1..10]
  elsif phone_number.length == 11 && phone_number[0] != 1
    'Incorrect number'
  end
end

def peak_registration(day)
  days = {0 => "Sunday", 1 => "Monday", 2 => "Tuesday", 3 => "Wednesday", 4 => "Thursday", 5 => "Friday", 6 => "Saturday"}
  day = days[day]
end

def name_of_week(array)
  array.map {|val| peak_registration(val)}
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    ).officials
  rescue
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id,form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

puts 'EventManager initialized.'

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter
count_hours = Hash.new(0)
count_days = Hash.new(0)

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  zipcode = clean_zipcode(row[:zipcode])
  legislators = legislators_by_zipcode(zipcode)

  phone = clean_phone_number(row[:homephone])
  regtime = DateTime.strptime(row[:regdate], "%m/%d/%y %H:%M")
  peak_hour = regtime.hour
  count_hours[peak_hour] += 1
  peak_day = regtime.wday 
  count_days[peak_day] += 1

  form_letter = erb_template.result(binding)

  save_thank_you_letter(id,form_letter)
end

hour_peak_view = []
day_peak_view = []

count_days.each do |k, v|
  day_peak_view.push(k) if v == count_days.values.max
end

count_hours.each do |k, v|
  hour_peak_view.push(k) if v == count_hours.values.max
end

puts "Peak registration hour(s): #{hour_peak_view}"
puts "Peak registration day: #{name_of_week(day_peak_view)}"