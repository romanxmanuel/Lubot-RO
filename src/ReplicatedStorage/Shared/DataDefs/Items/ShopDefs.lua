--!strict

local ShopDefs = {
    prontera_general_shop = {
        id = 'prontera_general_shop',
        name = 'Baazar Merchant',
        buyItems = {
            'red_potion',
            'blue_potion',
            'fly_wing',
            'butterfly_wing',
            'arrow_bundle_small',
            'sword',
            'rod',
            'bow',
            'cotton_shirt',
            'sandals',
            'guard',
        },
        sellableCategories = {
            Material = true,
            Consumable = true,
        },
    },
}

return ShopDefs
