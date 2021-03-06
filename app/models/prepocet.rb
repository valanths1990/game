# encoding: utf-8
class Prepocet
  def self.kompletni_prepocet
    ActiveRecord::Base.transaction do
      puts a = Time.now
      puts "PREPOCET"
      Prepocet.zamkni
      order = Prepocet.vytvor_eody
      Prepocet.zmen_vudce(order)
      Prepocet.zpristupni_planety
      Prepocet.produkce_suroviny(order)
      Prepocet.orbit_salary(order)
      Prepocet.zapis_suroviny
      Arrakis.kontrola_fremenu
      Prepocet.produkce_melanz(order)

      Prepocet.reset_vyhosteni
      Prepocet.udalosti

      Prepocet.kontrola_zakonu

      if Constant.pristi_volby == Date.today
        Prepocet.zvol_poslance
      end

      if Imperium.konec_volby_imperatora == Date.today
        Prepocet.zvol_imperatora
      end

      if User.spravce_arrakis
	      Constant.prepni_bezvladi_arrakis(nil)
      end

      Prepocet.prepocti_vliv

      Prepocet.odemkni
      puts b = Time.now
    end
  end

  def self.vytvor_eody
    order = User.find(1).eods.where(:date => Date.today).maximum(:order)
    if order
      order += 1
    else
      order = 1
    end

    for user in User.all do
	    mentats = user.house.mentate.collect { |p| [p.id] }.map(&:inspect).join(' ')
      Eod.new(
          :user_id => user.id,
          :date => Date.today,
          :time => Time.now,
          :order => order,
          :imperator => User.imperator ? User.imperator.id : {},
          :arrakis => User.spravce_arrakis ? User.spravce_arrakis.id : {},
          :leader => user.house.vudce ? user.house.vudce.id : {},
          :mentats => mentats
      ).save
    end
    puts "Eody vyvtoreny"
    return order
  end

  def self.reset_vyhosteni
	  House.all.each do |h|
		  h.update_attribute 'pocet_vyhosteni', 0 if h.pocet_vyhosteni > 0
	  end
  end

  def self.produkce_suroviny(order)
    for field in Field.includes(:user, :buildings, :resource).all do
	    field.set_popka_v_budovach_helper(field.resource.population)
      vlastnik = field.user
      narod = vlastnik.house if vlastnik
      if field.planet == Arrakis.planeta

      else
        enviro_pop = field.planet.udalost_bonus("L")
        effect_pop = field.leno_udalost_bonus("L")
        population_exp = vlastnik.tech_bonus("L")
        population_house_exp = narod.vyskumane_narodni_tech("L")
        population = (field.vynos('population') * population_exp * population_house_exp * enviro_pop * effect_pop * nahoda_produkce)
        #field.resource.update_attributes(:population => field.resource.population + population)
        field.set_popka_v_budovach_helper(field.resource.population + population)

        solar_exp = vlastnik.tech_bonus("S")
        enviro_solar = field.planet.udalost_bonus("S")
        effect_solar = field.leno_udalost_bonus("S")
        solar_house_exp = narod.vyskumane_narodni_tech("S")

        solar = (field.vynos('solar') * solar_exp * solar_house_exp * enviro_solar * effect_solar * nahoda_produkce).round(2)

        enviro_exp = field.planet.udalost_bonus("E")
        effect_exp = field.leno_udalost_bonus("E")
        exp_exp = vlastnik.tech_bonus("E")
        exp_house_exp = narod.vyskumane_narodni_tech("E")
        exp = (field.vynos('exp') * exp_exp * exp_house_exp * enviro_exp * effect_exp * nahoda_produkce).round(0)

        enviro_material = field.planet.udalost_bonus("M")
        effect_material = field.leno_udalost_bonus("M")
        material_exp = vlastnik.tech_bonus("M")
        material_house_exp = narod.vyskumane_narodni_tech("M")
        material = (field.vynos('material') * material_exp * material_house_exp * enviro_material * effect_material * nahoda_produkce).round(2)

        parts = field.vynos('parts').to_i #enviro_parts
        temp_mat = material
        material = material - parts * Constant.parts_mat_cost
        while field.resource.material + material < 0
	        parts -= 1
	        material = temp_mat - parts * Constant.parts_mat_cost
        end
        material = material.round(2)
        solar = (solar - field.salary).round(2)
        field.squads.each do |s|
		      while s.number > 0 && vlastnik.solar + solar < 0
		        field.predaj_jednotiek([[[1],[s.unit.name]]])
	        end
        end
        exp = exp.to_i
        if field.resource.population + population > field.capacity_population
	        population = 0
	        if field.resource.population > field.capacity_population
		        population = ((field.capacity_population - field.resource.population) / 2).to_i.abs * (-1)
	        else
		        population = (field.capacity_population - field.resource.population).to_i
	        end
        end
        vlastnik.update_attributes(
            :solar => vlastnik.solar + solar,
            :exp => vlastnik.exp + exp
        )
        field.resource.update_attributes(
            :material => field.resource.material + material,
            :population => field.resource.population + population,
            :parts => field.resource.parts + parts
        )
        Eod.new(
            :user_id => vlastnik.id,
            :field_id => field.id,
            :date => Date.today,
            :time => Time.now,
            :order => order,
            :solar_income => solar,
            :exp_income => exp,
            :material_income => material,
            :population_income => population,
            :parts_income =>  parts,
        ).save
      end
	    field.set_popka_v_budovach_helper(0)
    end
    puts "suroviny vyprodukovany "
  end

  def self.orbit_salary(order)
	  User.all.each do |u|
		  u.orbit_salary
		  Eod.new(
				  :user_id => u.id,
				  :date => Date.today,
				  :time => Time.now,
				  :order => order,
				  :solar_income => u.orbit_salary * (-1),
				  :exp_income => 0,
				  :material_income => 0,
				  :population_income => 0,
				  :parts_income =>  0,
		  ).save
		end
  end

  def self.zapis_suroviny
	  User.all.each do |u|
		  eod = u.eods.where(field_id: nil).last
			  if eod
			  eod.update_attributes(:solar_store => u.solar,
			                        :exp_store => u.exp,
			                        :material_store => u.celkovy_material,
			                        :population_store => u.celkova_populace,
			                        :melange_store => u.melange,
			                        :parts_store => u.celkovy_parts
			                        )
				end
	  end
	  puts "Suroviny zapsany do eod po produkcii."
  end

  def self.produkce_melanz(order)
    puts "PRODUKUJI MELANZ"
    arrakis = Arrakis.planeta
    leno = Field.find_by_planet_id(arrakis)
    vlastnik = User.spravce_arrakis
    #enviro_material = field.planet.udalost_bonus("M")
    user_tech = vlastnik.tech_bonus("J") if vlastnik
    house_tech = vlastnik.house.vyskumane_narodni_tech("J") if vlastnik
    if vlastnik
      melange = (leno.vynos('melange') * user_tech * house_tech * nahoda_produkce).round(2)
      melange = (melange * Constant.malus_melanz_bezvladi).round(2) if Constant.bezvladi_arrakis
    else
      melange = 0.0
    end
    Imperium.zapis_operaci("Bylo vytezeno #{melange} mg melanze.")
    Prepocet.rozdel_melanz(melange, order)
  end

  def self.nahoda_produkce
	  if Constant.zapnout_nahodnou_produkci == true
      ((100.0 + (Constant.modifikator_produkce / 2)) - rand(Constant.modifikator_produkce))/100
	  else
		  1
		end
  end

  def self.rozdel_melanz(melange, order)
    puts "ROZDELUJI MELANZ = " << melange.to_s
    #pocet = House.playable.count
    #podil = (melange / pocet).round(2)
    gilde = Prepocet.melanz_gilde(melange)
    Imperium.zapis_operaci("Vesmirne Gilde bylo odeslano #{gilde} mg melanze.")
    melange -= gilde
    odevzdano = 0.0
    House.playable.all.each do |house|
      rodu = melange * (house.melange_percent / 100.0)
      odevzdano += rodu
      house.zapis_operaci("Obdrzeno #{rodu} mg melanze.")
      #house.zapis_operaci("Obdrzeno #{rodu} mg melanze.")
      house.update_attribute(:melange, house.melange + rodu)

      # TODO dodelat update vsem userum rodu
      #for eod in user.eods.where(:date => Date.today, :field_id => nil, :order => order).all do
      #  eod.update_attribute(:melange_income, podil)
      #end
    end
    imperiu = melange - odevzdano
    Imperium.zapis_operaci("Do imperialnich skladu bylo odeslano #{imperiu} mg melanze.")
    imperium = House.imperium
    imperium.update_attribute(:melange, imperium.melange + imperiu)
  end

  def self.melanz_gilde(melange)
    gilde = melange * (Constant.gilda_melanz_procenta / 100.0)
    if gilde < Constant.gilda_melanz_pevna
      return Constant.gilda_melanz_pevna
    else
      return gilde
    end
  end

  def self.zpristupni_planety
    puts "Zpristupnuji planety"
    dostupno = Constant.planeta_dostupna_po.days.ago.to_date
    for planeta in Planet.objevene do
      if planeta.discovered_at < dostupno
        planeta.update_attribute(:available_to_all, true)
        Imperium.zapis_operaci("Zpristupnena planeta #{planeta.name} v systemu #{planeta.system_name} (#{planeta.system.id}).")
      end
    end
  end

  def self.zmen_vudce(order)
    houses = House.playable.includes(:users, :votes)
    houses.each do |house|
      puts "Delam #{house.name}"
      old_vudce = house.users.where(:leader => true).first
      new_vudce = house.kdo_je_vitez('leader')
      if old_vudce == new_vudce

      else
        o_vudce = 'nikdo'
        n_vudce = 'nikdo'
        if old_vudce
          old_vudce.update_attribute(:leader, false)
          old_vudce.zapis_operaci("Byl jsem sesazen z postu vudce.")
          unless house.poradi_hlasu('poslanec', house.pocet_poslancu).include?(old_vudce)
            old_vudce.update_attribute(:landsraad, true)
            old_vudce.zapis_operaci("Nadale nemam pristup do Landsraadu.")
          end
          o_vudce = old_vudce.nick
        end
        unless new_vudce.blank?
          new_vudce.update_attribute(:leader, true)
          new_vudce.zapis_operaci("Byl jsem zvolen novym vudcem.")
          #new_vudce.update_attribute(:landsraad, true)
          #new_vudce.zapis_operaci("Mam pristup do Landsraadu.")
          n_vudce = new_vudce.nick
        end
        house.zapis_operaci("Zvolen novy vudce #{n_vudce}.") unless n_vudce == 'nikdo'
        puts "Menim vudce #{o_vudce} na #{n_vudce}"
      end
      house.eod_zapis_vudce(order, new_vudce)
    end
    puts "vudcove zmeneni"
  end

  def self.odemkni
    Aplikace.odemkni_hru
    puts "hra odemcena"
  end

  def self.zamkni
    Aplikace.zamkni_hru
    puts "hra uzamcena"
  end



  def self.prepocti_vliv
    for h in House.playable do
      for u in h.users do
        vliv_hrace = u.vliv.round(2)
        u.update_attribute(:influence, vliv_hrace)
        u.zapis_operaci("Muj vliv je nyni: #{vliv_hrace}")
      end
      vliv_rodu = h.vliv
      h.update_attribute(:influence, vliv_rodu)
      h.zapis_operaci("Vliv naroda je nyni: #{vliv_rodu}")
    end
    celkovy_vliv = House.playable.sum(:influence).round(2)
    imp = House.imperium
    imp.update_attribute(:influence, celkovy_vliv)
    Imperium.zapis_operaci("Celkový vliv Impéria nyní činí #{celkovy_vliv}.")
  end

  def self.zvol_poslance
    houses = House.playable
    for h in houses do
      pocet_poslancu = h.pocet_poslancu
      for u in h.poslanci do
        u.update_attribute(:landsraad, false)
        u.zapis_operaci("Jiz nejsem poslancem.")
      end
      for u in h.poradi_hlasu('poslanec', pocet_poslancu) do
        u[0].update_attribute(:landsraad, true)
        u[0].zapis_operaci("Nyni jsem poslancem.")
      end
    end
    Global.prepni('pristi_volby', 2, 1.week.from_now)
  end

  def self.kontrola_zakonu
    Prepocet.ukonci_hlasovani
    Prepocet.zarad_zakony
  end

  def self.ukonci_hlasovani
    puts "Ukoncuji hlasovani"
    for law in Law.projednavane do
      if law.enacted.to_date < 2.days.ago.to_date
        law.vyhodnot_zakon
      end
    end
  end

  def self.zarad_zakony
    until Law.projednavane.count == 3 || Law.zarazene.count == 0
      Law.zarazene.order(:position).first.update_attributes(:state => Law::STATE[1], :enacted => Date.today)
    end
  end

  def self.zvol_imperatora
    old_imp = User.imperator
    old_reg = User.regenti

    if old_imp
      old_imp.update_attribute(:emperor, false)
      old_imp.zapis_operaci('Jiz dale nejsem Imperatorem.')
    end
    if old_reg
      for u in old_reg do
        u.update_attribute(:regent, false)
        u.zapis_operaci('Jiz dale nejsem Regentem.')
      end
    end

    imperium = House.imperium
    new_imp = imperium.poradi_hlasu('imperator', 3)
    pocet_hlasujicich = imperium.votes.where(:typ => 'imperator').count
    if new_imp[0] && new_imp[0][1] > pocet_hlasujicich * 0.6
      new_imp[0][0].update_attribute(:emperor, true)
      new_imp[0][0].zapis_operaci('Byl jsem zvolen Imperatorem.')
      Imperium.zapis_operaci("Byl zvolen nový Imperátor - #{new_imp[0][0].nick}.")
    else
      regnick = ''
      for u in new_imp do
        u[0].update_attribute(:regent, true)
        u[0].zapis_operaci("Byl jsem zvolen Regentem.")
        regnick += u[0].nick + ' '
      end
      Imperium.zapis_operaci("Byla zvolena Regentská vláda - #{regnick}.")
    end

    if new_imp
      #Global.prepni('konec_volby_imperatora', 2, 2.week.from_now)
      Global.prepni('volba_imperatora', 1, false)
    end
    Vote.imperatorske.delete_all
  end

  def self.udalosti
	  if Constant.start_veku + Constant.pocet_dni_bez_udalosti_od_zac_veku.days < Constant.start_veku
	  puts 'udalosti'
		  Planet.nahodna_udalost
		  puts 'Enviroments done'

		  Field.udalosti_lena
		  puts 'Effects done'
	  end

  end


end
