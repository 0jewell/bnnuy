export type config = {
    experience: {
        id: number,
        badges: { [string]: badge_settings }?,
        passes: { [string]: gamepass_settings }?,
        products: { [string]: product_settings }?,
    }
}

export type badge_settings = {
    name: string,
    description: string,
    icon: string,
    enabled: boolean?,
}

export type gamepass_settings = {
    name: string,
    description: string,
    icon: string,
    forSale: boolean?,
    price: number?,
}

export type product_settings = {
    name: string,
    description: string,
    icon: string,
    price: number,
    [string]: any,
}

return nil