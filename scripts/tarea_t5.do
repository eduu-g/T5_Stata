
* Autor: Eduardo Guerrero
* Fecha: 19/11/2026
*
* Base utilizada: data/raw/casen_reducido.csv
* Resultados: output/tarea_t5.log y output/tarea_t5_por_sector.xlsx

version 14
clear all
set more off
capture log close
capture mkdir "output"

* PARÁMETROS DE CONFIGURACIÓN

* Las macros local se usan porque sus valores solo se necesitan dentro de este
* do-file; así no quedan definiciones locales innecesarias en otros scripts.
local datos          "data/raw/casen_reducido.csv"
local archivo_log    "output/tarea_t5.log"
local archivo_excel  "output/tarea_t5_por_sector.xlsx"
local depvar         "ingreso"
local numericas      "ingreso educ edad experiencia"
local controles      "educ experiencia"
local grupos         "sector region genero"

* La macro global se usa para el umbral porque podría compartirse con otros
* do-files del mismo proyecto. El umbral se define en un solo lugar.
global umbral = 50000

* Aqui se muestra la carpeta desde la que se está ejecutando el do-file.
display as text "Carpeta de trabajo de Stata:"
pwd

* Comprobamos que la base existe antes de iniciar el análisis.
capture confirm file "`datos'"
if _rc != 0 {
    display as error "No se encuentra `datos'. Ejecuta Stata desde la carpeta principal del proyecto."
    exit 601
}

log using "`archivo_log'", replace text

display as text "T5 — Do-file automatizado"
display as text "Archivo de datos: `datos'"
display as text "Variable dependiente: `depvar'"
display as text "Controles: `controles'"
display as text "Umbral de ingreso: $" %12.0f $umbral


* CARGAR Y PREPARAR LOS DATOS

import delimited "`datos'", clear varnames(1) encoding("utf-8")

* La experiencia potencial se calcula como edad - educación - 6.
* max() evita que se generen valores negativos.
generate experiencia = max(edad - educ - 6, 0)
label variable experiencia "Experiencia potencial (edad - educacion - 6)"

* Creamos una variable indicadora: 1 = mujer; 0 = hombre.
generate byte mujer = (genero == "F") if !missing(genero)
label define mujer_lbl 0 "Hombre" 1 "Mujer"
label values mujer mujer_lbl
label variable mujer "Indicadora de mujer (1 = Mujer)"

* Revisamos la estructura y las variables recién creadas.
describe
count
summarize experiencia mujer


* FOREACH: DESCRIPTIVOS DE LAS VARIABLES NUMÉRICAS

* Una sola estructura permite resumir todas las variables de la lista.
foreach v of local numericas {
    display _newline as text "===== Resumen detallado: `v' ====="
    summarize `v', detail
}


* FORVALUES: PERSONAS POR TRAMOS DE EDUCACIÓN

* Cada tramo contiene cuatro años: 4–7, 8–11, 12–15, 16–19 y 20–23.
* Se incluye el último tramo para no dejar fuera observaciones con educ = 20.
forvalues t = 4(4)20 {
    local limite = `t' + 3
    quietly count if educ >= `t' & educ <= `limite'
    local n_tramo = r(N)
    display as text "Educación de `t' a `limite' años: " ///
        as result %4.0f `n_tramo' as text " personas"
}


* PROGRAMA REUTILIZABLE: DESCRIPTIVOS POR GRUPO

capture program drop descriptivos_grupo
program define descriptivos_grupo
    * El primer argumento indica la variable de agrupación.
    args variable

    display _newline as text "===== Descriptivos por `variable' ====="

    * tabulate/tabstat trabajan con una variable numérica de grupo.
    * Si el argumento es texto, encode crea una versión numérica temporal
    * con etiquetas; si ya es numérico, se copia a una variable temporal.
    tempvar grupo_n
    capture confirm string variable `variable'
    if _rc == 0 {
        encode `variable', generate(`grupo_n')
    }
    else {
        generate long `grupo_n' = `variable'
    }

    tabulate `grupo_n'
    tabstat ingreso educ, by(`grupo_n') statistics(mean sd n)
end

* Un único loop llama al mismo programa para los tres grupos configurados.
foreach g of local grupos {
    descriptivos_grupo `g'
}


* TEMPVAR: VARIABLE INTERMEDIA TEMPORAL

tempvar ing_miles
generate double `ing_miles' = ingreso / 1000
label variable `ing_miles' "Ingreso mensual en miles de pesos"
summarize `ing_miles'

* tempvar es más seguro que crear una variable permanente y borrarla después:
* Según lo que me explicó la IA a la que le consulté pór este codigo,
* Stata asigna un nombre temporal único y elimina la variable automáticamente
* al terminar el ámbito del do-file, evitando dejar variables auxiliares.


* MISSING: FILTRAR INGRESOS SOBRE EL UMBRAL

count if `depvar' > $umbral & !missing(`depvar')
local n_sobre_umbral = r(N)
display as text "Personas con ingreso válido superior al umbral: " ///
    as result `n_sobre_umbral'

* En Stata los missing numéricos (.) se ordenan por encima de cualquier número.
* Sin & !missing(ingreso), los ingresos faltantes también cumplirían ingreso >
* 500000 y serían contados incorrectamente como si superaran el umbral.


* DOS MODELOS, ESTIMATES STORE Y COMPARACIÓN

* Modelo 1: ingreso explicado por educación y experiencia potencial.
quietly regress `depvar' `controles'
estimates store m1

* Modelo 2: misma especificación y además la indicadora de mujer.
quietly regress `depvar' `controles' i.mujer
estimates store m2

* Comparamos coeficientes, errores estándar, N y R-cuadrado.
display _newline as text "===== Comparación de modelos ====="
estimates table m1 m2, b(%9.0f) se stats(N r2) stfmt(%9.3f)

* Mostrar el coeficiente de educación desde el modelo 2, sin copiarlo a mano.
estimates restore m2
display as text "Coeficiente de educación en m2 (pesos por año adicional): " ///
    as result %12.0f _b[educ]

* Guardamos también el coeficiente de mujer para facilitar su lectura.
display as text "Coeficiente de mujer en m2 (diferencia respecto de hombres, pesos): " ///
    as result %12.0f _b[1.mujer]

* 9. REGRESIÓN POR SECTOR: MATRIZ J() Y EXPORTACIÓN CON PUTEXCEL

* Se crea una codificación numérica temporal de sector para poder obtener sus
* niveles y recorrerlos con foreach. Las etiquetas conservan los nombres.
tempvar sector_id
encode sector, generate(`sector_id') label(sector_lbl)
levelsof `sector_id', local(sectores)
local nsectores : word count `sectores'

* Tres columnas: coeficiente de educación, error estándar y número de casos.
matrix resultados_sector = J(`nsectores', 3, .)
matrix colnames resultados_sector = coef_educ se_educ N

local i = 1
foreach s of local sectores {
    quietly regress `depvar' educ if `sector_id' == `s'

    matrix resultados_sector[`i', 1] = _b[educ]
    matrix resultados_sector[`i', 2] = _se[educ]
    matrix resultados_sector[`i', 3] = e(N)

    local i = `i' + 1
}

* Creamos el Excel: nombres de los sectores en A y matriz numérica en B:D.
putexcel set "`archivo_excel'", replace sheet("Por sector")
putexcel A1 = ("Sector") ///
         B1 = ("Coeficiente educación (pesos)") ///
         C1 = ("Error estándar") ///
         D1 = ("N")

local i = 1
foreach s of local sectores {
    local nombre : label sector_lbl `s'
    local fila = `i' + 1
    putexcel A`fila' = ("`nombre'")
    local i = `i' + 1
}

putexcel B2 = matrix(resultados_sector)

* También mostrar la matriz en Results para revisar los valores en Stata.
display _newline as text "===== Resultados de las regresiones por sector ====="
matrix list resultados_sector


* INTERPRETACIÓN Y CIERRE DEL LOG

* Considerando los 55 casos con ingresos válidos, se observa que:
* En el modelo 1, cada año adicional de educación se relaciona con
* un ingreso mensual aproximadamente $42.019 mayor, manteniendo
* constante la experiencia potencial.
* En el modelo 2, esta cifra cambia poco y llega a $42.246. La variable
* mujer presenta una diferencia de -$55.686 frente a los hombres,
* pero no es estadísticamente significativa al 5 %. Por sector, las
* muestras van de 5 a 15 personas, por lo que algunas estimaciones
* son poco precisas. Además, la muestra es reducida y puede no
* representar a toda la población. Los resultados muestran asociaciones,
* pero no permiten afirmar que una variable cause cambios en otra.

log close
