module SuperAdmin::FeaturesHelper
  def self.available_features
    YAML.load(ERB.new(Rails.root.join('app/helpers/super_admin/features.yml').read).result).with_indifferent_access
  end

  def self.plan_details
    plan = ChatwootHub.pricing_plan
    quantity = ChatwootHub.pricing_plan_quantity

    if plan == 'premium'
      "Você está atualmente no plano <span class='font-semibold'>#{plan}</span> com <span class='font-semibold'>#{quantity} agentes</span>."
    else
      "Você está atualmente no plano da edição <span class='font-semibold'>#{plan}</span>."
    end
  end
end
