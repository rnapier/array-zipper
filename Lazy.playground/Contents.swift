let xs = [3, 1, 4, 1, 5, 9, 2, 6, 5, 3, 5, 8, 9, 7, 9, 3, 1]

let _:() = {
    let smalldoublexs = xs
        .map { $0 * 2 }
        .filter { $0 < 10 }
    }()

let _:() = {
    var doublexs = [Int]()
    for x in xs {
        doublexs.append(x * 2)
    }
    var smalldoublexs = [Int]()
    for x in doublexs {
        if x < 10 {
            smalldoublexs.append(x)
        }
    }
    smalldoublexs
}()

let _:() = {
    var smalldoublexs = [Int]()
    for x in xs {
        let doublex = x * 2
        if doublex < 10 {
            smalldoublexs.append(doublex)
        }
    }
    smalldoublexs
}()

let _:() = {
    var smalldoublexs = [Int]()
    for x in xs {
        let doublexthunk = {x * 2}

        let doublex = doublexthunk()
        if doublex < 10 {
            smalldoublexs.append(doublex)
        }
    }
    smalldoublexs
    }()

let _:() = {
    let xs = [3, 1, 4, 1, 5, 9, 2, 6, 5, 3, 5, 8, 9, 7, 9, 3, 1]
    let doublexs = lazy(xs)
        .map { $0 * 2 }
    let doubleSecond = doublexs[1]
}()


let _:() = {
    let doublexs = lazy(xs)
        .map { x -> Int in println("Double"); return x * 2 }
    println("---")
    println(doublexs[1])
    println("---")
    println(doublexs[1])
    println(doublexs)
}()

let _:() = {
    for x in xs.map({ $0 * 2 }) {
        println(x)
    }
}()
