require 'date'
require 'json'

def main
  plan_file = ARGV.shift
  data = JSON.parse(File.read(plan_file))
  plan = Plan.new data

  loop do
    latest_day = plan.days.last
    print_day latest_day
    puts
    next_date = latest_day.date + 1
    next_day = {
      'month' => next_date.month,
      'day' => next_date.day,
      'passages' => []
    }

    passage_title = "Enter passages for #{next_date.formatted}:"
    puts passage_title
    puts '-' * passage_title.length

    latest_day.passages.each do |passage|
      puts
      new_passage = {}

      default_book = continuing_book passage
      loop do
        print "Book (#{default_book}): "
        book = gets.chomp
        new_passage['book'] = book == '' ? default_book : book
        break if book_info new_passage['book']

        puts "Invalid book: #{new_passage['book']}"
      end

      new_passage['start'] = {
        'chapter' => input_chapter('Start chapter', default: continuing_chapter(passage)),
        'verse' => input_verse('Start verse', default: continuing_verse(passage))
      }
      new_passage['start'].delete 'verse' if new_passage['start']['verse'].nil?

      default_end_verse = nil
      default_end_verse = new_passage['start']['verse'] + 1 if new_passage['start']['verse']

      new_passage['end'] = {
        'chapter' => input_chapter('End chapter', default: new_passage['start']['chapter']),
        'verse' => input_verse('End verse', default: default_end_verse)
      }
      new_passage['end'].delete 'verse' if new_passage['end']['verse'].nil?

      next_day['passages'] << new_passage
    end

    puts
    print_day Plan::Day.new next_day
    puts

    answer = nil
    loop do
      print 'Is this correct? (y/n): '
      answer = gets.chomp
      break if %[y n].include? answer.downcase

      puts "Please enter 'y' or 'n'"
    end

    if answer.downcase == 'y'
      data << next_day
      File.write plan_file, JSON.pretty_generate(data)
    end
  end
end

def print_day(day)
  puts "Date: #{day.date.formatted}"
  puts
  passages = day.passages
  puts "Passages: #{format_passage(passages[0])}"
  passages[1..-1].each do |passage|
    puts "          #{format_passage(passage)}"
  end
end

def format_passage(passage)
  formats = locale['formats']

  passage_start = passage['start']
  passage_end = passage['end']
  if !passage_start.key?('verse')
    if passage_start['chapter'] == passage_end['chapter']
      result = formats['chapter'].dup
      result.gsub!('{book}', format_book(passage['book']))
      result.gsub!('{chapter}', passage_start['chapter'].to_s)
    else
      result = formats['chapter_range'].dup
      result.gsub!('{book}', format_book(passage['book']))
      result.gsub!('{start_chapter}', passage_start['chapter'].to_s)
      result.gsub!('{end_chapter}', passage_end['chapter'].to_s)
    end
  elsif passage_start['chapter'] == passage_end['chapter']
    result = formats['verse_range_same_chapter'].dup
    result.gsub!('{book}', format_book(passage['book']))
    result.gsub!('{chapter}', passage_start['chapter'].to_s)
    result.gsub!('{start_verse}', passage_start['verse'].to_s)
    result.gsub!('{end_verse}', passage_end['verse'].to_s)
  end
end

def format_book(book)
  locale['books'][book]
end

def locale
  @locale ||= JSON.parse File.read('./locales/en.json')
end

def continuing_book(passage)
  return next_book(passage) if until_end_of_book? passage

  passage['book']
end

def next_book(passage)
  book_index = books.index { |book| book['id'] == passage['book'] }
  books[book_index + 1]['id']
end

def until_end_of_book?(passage)
  info = book_info passage['book']
  return false unless passage['end']['chapter'] == info['chapter_count']
  return true unless passage['end'].key? 'verse'

  passage_end['verse'] == info['verse_counts'][passage['end']['chapter'] - 1]
end

def continuing_chapter(passage)
  return 1 if until_end_of_book? passage
  return next_chapter(passage) if until_end_of_chapter? passage

  passage['end']['chapter']
end

def next_chapter(passage)
  passage['end']['chapter'] + 1
end

def input_chapter(label, default:)
  loop do
    print "#{label} (#{default}): "
    chapter = gets.chomp
    result = chapter == '' ? default : chapter.to_i
    return result if result.positive?

    puts "Invalid chapter: #{chapter}"
  end
end

def continuing_verse(passage)
  return nil unless passage['end'].key? 'verse'
  return 1 if until_end_of_chapter?(passage)

  passage['end']['verse'] + 1
end

def until_end_of_chapter?(passage)
  return true unless passage['end'].key? 'verse'

  info = book_info passage['book']
  passage['end']['verse'] == info['verse_counts'][passage['end']['chapter'] - 1]
end

def input_verse(label, default:)
  loop do
    print "#{label} (#{default || 'none'}): "
    verse = gets.chomp
    return nil if verse == 'none'

    result = verse == '' ? default : verse.to_i
    return result if result.nil? || result.positive?

    puts "Invalid verse: #{verse}"
  end
end

def book_info(book_id)
  books.find { |book| book['id'] == book_id }
end

def books
  @books ||= JSON.parse File.read('./books.json')
end

class Plan
  def initialize(data)
    @data = data
  end

  def days
    @data.map { |day|
      Day.new day
    }
  end

  class Day
    def initialize(data)
      @data = data
    end

    def passages
      @data['passages']
    end

    def date
      @date ||= DateWithoutYear.new @data['month'], @data['day']
    end
  end
end

class DateWithoutYear
  def initialize(month, day)
    @date = Date.new(2001, month, day)
  end

  def month
    @date.month
  end

  def day
    @date.day
  end

  def formatted
    @date.strftime('%b %-d')
  end

  def +(other)
    new_date = @date + other
    DateWithoutYear.new new_date.month, new_date.day
  end
end

main
