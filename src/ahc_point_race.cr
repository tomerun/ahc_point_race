require "html_builder"
require "json"
require "yaml"

GP30 = [
  100, 75, 60, 50, 45, 40, 36, 32, 29, 26,
  24, 22, 20, 18, 16, 15, 14, 13, 12, 11,
  10, 9, 8, 7, 6, 5, 4, 3, 2, 1,
]

record Contest, name : String, writer : Array(String), is_long : Bool

struct Writer
end

class Person
  getter :name

  def initialize(@name : String)
    @scores = [] of Int32 | Writer | Nil
  end

  def [](i : Int32)
    return case v = @scores.fetch(i, nil)
    when Int32
      v.to_s
    when Writer
      "W"
    else
      "-"
    end
  end

  def is_ranker?
    return @scores.any? { |v| v.is_a?(Writer) || (v.is_a?(Int32) && v.as(Int32) > 0) }
  end

  def conclude(size)
    while @scores.size < size
      @scores << nil
    end
  end

  def add_score(v, idx)
    while @scores.size < idx
      @scores << nil
    end
    @scores << v
  end

  def count_participate
    return @scores.count { |v| v.is_a?(Int32) }
  end

  def sum
    sum = sum_raw
    writer = @scores.count { |v| v.is_a?(Writer) }
    return sum + sum / (@scores.size - writer) * writer
  end

  def ave
    return sum_raw / count_participate
  end

  def sum_raw
    return @scores.select { |v| v.is_a?(Int32) }.map { |v| v.as(Int32) }.sum
  end
end

def load_persons(contests : Array(Contest)) : Array(Person)
  ps = Hash(String, Person).new
  contests.each_with_index do |contest, i|
    json = JSON.parse(File.read("data/#{contest.name}.json"))
    json["StandingsData"].as_a.each do |p|
      if !p["IsRated"].as_bool
        next
      end
      name = p["UserScreenName"].as_s
      rank = p["Rank"].as_i
      point = rank <= 30 ? GP30[rank - 1] : 0
      if ps.has_key?(name)
        p = ps[name]
      else
        p = Person.new(name)
        ps[name] = p
      end
      p.add_score(point, i)
    end
    contest.writer.each do |w|
      if ps.has_key?(w)
        p = ps[w]
      else
        p = Person.new(w)
        ps[w] = p
      end
      p.add_score(Writer.new, i)
    end
  end
  rankers = ps.values.select(&.is_ranker?)
  rankers.each { |p| p.conclude(contests.size) }
  return rankers
end

def output(year : Int32, years : Array(Int32), contests : Array(Contest), persons : Array(Person))
  html = HTML.build do
    doctype
    html() do
      head do
        title { text "AtCoder Heuristic Race Ranking (Unofficial)" }
        tag("meta", charset: "UTF-8") { }
        # meta(charset: "UTF-8")
        link(href: "./style.css", rel: "stylesheet")
      end
      html "\n"
      body do
        h1 { text "AtCoder Heuristic Race Ranking (Unofficial) - #{year}" }
        html "\n"
        div(class: "link") {
          span(class: "link_element") { a(href: "https://github.com/tomerun/ahc_point_race") { text "GitHub" } }
          span { text "|" }
          years.each do |y|
            if y == year
              span(class: "link_element") { text y.to_s }
            else
              span(class: "link_element") { a(href: "./#{y}.html") { text y.to_s } }
            end
          end
        }
        html "\n"
        table {
          tag ("colgroup") {
            tag("col") { } # place
            tag("col") { } # name
            contests.each do |contest|
              tag("col", class: contest.is_long ? "long" : "short") { }
            end
            tag("col") { } # total
            tag("col") { } # participate
            tag("col") { } # average
          }
          thead {
            tr {
              td { text "place" }
              td { text "name" }
              contests.each do |contest|
                td(class: "contest_title") { a(href: "https://atcoder.jp/contests/#{contest.name}") { text contest.name } }
              end
              td(class: "total") { text "total" }
              td { text "participate" }
              td { text "average" }
            }
            html "\n"
          }
          tbody {
            persons.each.with_index do |p, i|
              tr {
                td(class: "place") { text (i + 1).to_s }
                td { a(href: "https://atcoder.jp/users/#{p.name}?contestType=heuristic") { text p.name } }
                contests.size.times do |j|
                  td(class: "score") { text p[j] }
                end
                td(class: "score total") do
                  s = p.sum
                  if s == s.to_i
                    text s.to_i.to_s
                  else
                    text sprintf("%.2f", s)
                  end
                end
                td(class: "score") { text p.count_participate.to_s }
                td(class: "score") { text p.count_participate == 0 ? "-" : sprintf("%.3f", p.ave) }
              }
              html "\n"
            end
          }
        }
      end
    end
  end
  File.open("publish/#{year}.html", "w") do |f|
    f.print(html)
  end
end

def create(year : Int32, years : Array(Int32), contests : Array(Contest))
  ps = load_persons(contests)
  output(year, years, contests, ps.sort_by { |p| {-p.sum, -p.count_participate, p.name} })
end

def main
  config = File.open("data/config.yml") do |f|
    YAML.parse(f)
  end.as_h
  years = config.keys.map(&.as_i)
  years.each do |y|
    contests = config[y].as_a.map do |c|
      Contest.new(c["name"].as_s, c["writer"].as_a.map(&.as_s), c["long"].as_bool)
    end
    create(y, years, contests)
  end
end

main
