# require "xlsxtream"

class QPCRGenerator
  PLATE_SIZE = {96 => {row_count: 8, column_count: 12}, 384 => {row_count: 16, column_count: 24} }

  def initialize(max_well_count, sample_list, reagent_list, replicate_count)
    raise ArgumentError.new("Invalid plate size (96 or 384)") unless [96, 384].include?(max_well_count)
    raise ArgumentError.new("Inconsistent number of experiments") unless
      reagent_list.length == sample_list.length && replicate_count.length == sample_list.length
    raise ArgumentError.new("Samples and reagents used in each experiment must be unique") unless
      (sample_list + reagent_list).all? {|exp| exp.uniq.length == exp.length }

    @max_well_count = max_well_count
    @plate_layout = PLATE_SIZE[max_well_count]
    @sample_list = sample_list
    @reagent_list = reagent_list
    @replicate_count = replicate_count
    @experiment_count = sample_list.length
    @plates = []
  end

  def new_plate
    Array.new(@plate_layout[:row_count]) { |column| Array.new(@plate_layout[:column_count]) }
  end

  def initialized_experiments
    (0...@sample_list.length).map do |experiment_index|
      experiment_combos = @sample_list[experiment_index].map do |sample|
        sample_combos = @reagent_list[experiment_index].map { |reagent| [sample, reagent] } * @replicate_count[experiment_index]
        sample_combos.sort!
      end
    end
  end

  def split_experiments(experiments)
    experiments.each_with_index do |experiment, i|
      next if experiment.first.length <= @plate_layout[:column_count]
      experiments[i] = nil
      experiments += split_experiment_by_columns(experiment)
    end
    experiments.compact!

    experiments.each_with_index do |experiment, i|
      next if experiment.length <= @plate_layout[:row_count]
      experiments[i] = nil
      experiments += split_experiment_by_rows(experiment)
    end
    experiments.compact
  end

  def split_experiment_by_columns(experiment)
    split_at_col_indices = experiment.first.map.with_index { |well, index| index if well[1] != experiment.first[index-1][1]}.compact
    split_at_col_indices.map.with_index do |split_index, i|
      experiment.map do |row|
        if split_at_col_indices[i] == split_at_col_indices.last
          row[split_at_col_indices[i]..-1]
        else
          row[split_at_col_indices[i]...split_at_col_indices[i+1]]
        end
      end
    end
  end

  def split_experiment_by_rows(experiment)
    split_count = experiment.length / @plate_layout[:row_count]
    (0..split_count).to_a.map do |i|
      experiment[(i * @plate_layout[:row_count])...((i * @plate_layout[:row_count]) + @plate_layout[:row_count])]
    end
  end

  def empty_well_positions(plate)
    plate
      .map.with_index { |row, i| [i, row.index(nil)] if row.index(nil) }
      .compact.to_h
  end

  def add_experiment_to_plate(starting_row_index, starting_column_index, experiment, plate)
    ending_row_index = starting_row_index + experiment.length
    ending_column_index = starting_column_index + experiment.first.length

    plate.each_with_index do |row, index|
      if index.between?(starting_row_index, ending_row_index)
        row.fill(starting_column_index...ending_column_index) do |i|
          experiment[(index - starting_row_index)][(i - starting_column_index)] if experiment[(index - starting_row_index)]
        end
      end
    end
  end

  def filled_plates
    unplaced_experiments = split_experiments(initialized_experiments)
    unplaced_experiments.sort_by!(&:length)
    unplaced_experiments.reverse!
    plate_counter = 0

    until unplaced_experiments.empty?
      @plates[plate_counter] ||= new_plate

      unplaced_experiments.each_with_index do |experiment, index|
        empty_well_positions(@plates[plate_counter]).each do |row_i, column_i|
          remaining_rows = @plate_layout[:row_count] - row_i
          remaining_columns = @plate_layout[:column_count] - column_i
          if experiment.length <= remaining_rows && experiment.first.length <= remaining_columns
            add_experiment_to_plate(row_i, column_i, experiment, @plates[plate_counter])
            unplaced_experiments[index] = nil
            break
          end
        end
      end

      unplaced_experiments.compact!
      plate_counter += 1
    end
    @plates
  end

  def set_color_codes
    reagents = @reagent_list.flatten.uniq
    color_codes = reagents.map { |reagent| [reagent, (0..2).map{"%0x" % (rand * 0x80 + 0x80)}.join] }.to_h
    return color_codes
  end
end
