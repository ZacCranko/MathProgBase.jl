
type LinprogSolution
    status
    objval
    sol
    attrs
end

typealias InputVector{T<:Real} Union(Vector{T},Real)

function expandvec(x,len::Integer)
    if isa(x,Vector)
        if length(x) != len
            error("Input size mismatch. Expected vector of length $len but got $(length(x))")
        end
        return x
    else
        return fill(x,len)
    end
end



function linprog(c::InputVector, A::AbstractMatrix, rowlb::InputVector, rowub::InputVector, lb::InputVector, ub::InputVector, solver::AbstractMathProgSolver = defaultLPsolver)
    m = model(solver)
    nrow,ncol = size(A)

    c = expandvec(c, ncol)
    rowlbtmp = expandvec(rowlb, nrow)
    rowubtmp = expandvec(rowub, nrow)
    lb = expandvec(lb, ncol)
    ub = expandvec(ub, ncol)
    
    # rowlb is allowed to be vector of senses
    if eltype(rowlbtmp) == Char
        realtype = eltype(rowubtmp)
        sense = rowlbtmp
        rhs = rowubtmp
        @assert realtype <: Real
        rowlb = Array(realtype, nrow)
        rowub = Array(realtype, nrow)
        for i in 1:nrow
            if sense[i] == '<'
                rowlb[i] = typemin(realtype)
                rowub[i] = rhs[i]
            elseif sense[i] == '>'
                rowlb[i] = rhs[i]
                rowub[i] = typemax(realtype)
            elseif sense[i] == '='
                rowlb[i] = rhs[i]
                rowub[i] = rhs[i]
            else
                error("Unrecognized sense '$(sense[i])'")
            end
        end
    else
        rowlb = rowlbtmp
        rowub = rowubtmp
    end
    
    loadproblem!(m, A, lb, ub, c, rowlb, rowub, :Min)
    optimize!(m)
    stat = status(m)
    if stat == :Optimal
        attrs = Dict()
        attrs[:redcost] = getreducedcosts(m)
        attrs[:lambda] = getconstrduals(m)
        return LinprogSolution(stat, getobjval(m), getsolution(m), attrs)
    elseif stat == :Infeasible
        attrs = Dict()
        try
            attrs[:infeasibilityray] = getinfeasibilityray(m)
        catch
            error("Infeasibility ray is unavailable; consider turning solver presolve off")
        end
        return LinprogSolution(stat, nothing, [], attrs)
    elseif stat == :Unbounded
        attrs = Dict()
        try
            attrs[:unboundedray] = getunboundedray(m)
        catch
            error("Unbounded ray is unavailable; consider turning solver presolve off")
        end
        return LinprogSolution(stat, nothing, [], attrs)
    else
        return LinprogSolution(stat, nothing, [], Dict())
    end
end

linprog(c,A,rowlb,rowub, solver::AbstractMathProgSolver = defaultLPsolver) = linprog(c,A,rowlb,rowub,0,Inf, solver)

export linprog


