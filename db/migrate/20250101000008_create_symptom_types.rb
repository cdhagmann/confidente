class CreateSymptomTypes < ActiveRecord::Migration[8.1]
  def change
    create_table :symptom_types do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.string :category
      # category groups symptoms for correlation analysis:
      # "gut" (bloating, cramping, diarrhea) vs "systemic" (headache, skin, fatigue)
      # histamine tends systemic, FODMAPs tend gut

      t.timestamps
    end

    add_index :symptom_types, :slug, unique: true
  end
end
